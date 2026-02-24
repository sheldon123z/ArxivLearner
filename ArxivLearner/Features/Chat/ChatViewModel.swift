import Foundation
import Observation
import SwiftData

// MARK: - ChatContextStrategy

/// Determines how paper content is injected into the LLM context window.
enum ChatContextStrategy {

    /// The paper's full text fits comfortably within the context window (< 50 % used).
    case fullTextInjection
    /// The paper's text exceeds 50 % of the context window; use keyword-based segment selection.
    case segmentMatching
    /// The model accepts a PDF file directly as input.
    case pdfDirect
    /// No markdown and no PDF capability — fall back to the abstract only.
    case plainTextFallback

    // MARK: - Resolution

    /// Resolves the best strategy for the given paper and model context-window size.
    ///
    /// - Parameters:
    ///   - paper: The paper whose content will be injected.
    ///   - contextWindow: Maximum number of *characters* the model accepts (approximate).
    /// - Returns: The most capable strategy that fits within the context window.
    static func resolve(paper: Paper, contextWindow: Int) -> ChatContextStrategy {
        // Prefer markdown content; fall back to abstract.
        let content = paper.markdownContent ?? paper.abstractText
        let contentLength = content.count

        // Use 50 % of the context window as the threshold, reserving the rest for
        // conversation history and the model's own response.
        let threshold = contextWindow / 2

        if paper.markdownContent != nil {
            if contentLength <= threshold {
                return .fullTextInjection
            } else {
                return .segmentMatching
            }
        } else {
            // No markdown available; abstract always fits.
            return .plainTextFallback
        }
    }

    // MARK: - Context Building

    /// Builds a system-prompt string for the chat session using this strategy.
    ///
    /// - Parameters:
    ///   - paper: The paper being discussed.
    ///   - userQuery: The latest user query (used for keyword matching in `segmentMatching`).
    /// - Returns: The assembled context string to embed in the system message.
    func buildSystemContext(for paper: Paper, userQuery: String = "") -> String {
        switch self {
        case .fullTextInjection:
            let body = paper.markdownContent ?? paper.abstractText
            return ChatViewModel.baseSystemPrompt + "\n\n---\n\n标题: \(paper.title)\n\n\(body)"

        case .segmentMatching:
            let segments = extractRelevantSegments(from: paper, query: userQuery)
            return ChatViewModel.baseSystemPrompt + "\n\n---\n\n标题: \(paper.title)\n\n以下是与问题最相关的论文片段：\n\n\(segments)"

        case .pdfDirect:
            // For MVP this path is not yet implemented; fall through to plainText.
            return ChatViewModel.baseSystemPrompt + "\n\n---\n\n标题: \(paper.title)\n\n摘要: \(paper.abstractText)"

        case .plainTextFallback:
            return ChatViewModel.baseSystemPrompt + "\n\n---\n\n标题: \(paper.title)\n\n摘要: \(paper.abstractText)"
        }
    }

    // MARK: - Segment Matching (simplified keyword approach)

    private func extractRelevantSegments(from paper: Paper, query: String) -> String {
        guard let markdown = paper.markdownContent else {
            return paper.abstractText
        }

        // Split by double-newline to get paragraph-level segments.
        let paragraphs = markdown.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        // Score each paragraph by how many query keywords it contains.
        let keywords = query
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }   // ignore very short words

        guard !keywords.isEmpty else {
            // No keywords — just take the first ~3 paragraphs as overview.
            return paragraphs.prefix(3).joined(separator: "\n\n")
        }

        let scored: [(score: Int, text: String)] = paragraphs.map { paragraph in
            let lower = paragraph.lowercased()
            let score = keywords.reduce(0) { count, kw in
                count + (lower.contains(kw) ? 1 : 0)
            }
            return (score, paragraph)
        }

        // Take the top 5 scoring paragraphs in their original order.
        let topIndices = scored
            .enumerated()
            .sorted { $0.element.score > $1.element.score }
            .prefix(5)
            .map { $0.offset }
            .sorted()

        let selected = topIndices.map { paragraphs[$0] }.joined(separator: "\n\n")
        return selected.isEmpty ? paragraphs.prefix(3).joined(separator: "\n\n") : selected
    }
}

// MARK: - ChatViewModel

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Public State

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?

    /// The paper currently loaded into this chat session.
    var paper: Paper?

    // MARK: - Private State

    private var streamTask: Task<Void, Never>?
    private var llmService: LLMServiceProtocol?

    /// The context window size (in characters) used for strategy resolution.
    /// Using a conservative estimate: 128 k tokens * ~4 chars/token = ~512 000 chars.
    private let contextWindow = 512_000

    // MARK: - System Prompt

    static let baseSystemPrompt: String = """
    你是一位专业的学术论文助手，擅长分析和解读人工智能与机器学习领域的研究论文。\
    请使用中文回答所有问题，语言简洁清晰，适合研究人员和学生阅读。\
    在分析论文时，请重点关注：研究问题、核心方法、实验结果以及对领域的贡献。\
    如遇到专业术语，可保留英文原文并附上中文解释。\
    用户提出的每个问题都基于已提供的论文内容进行回答，不要捏造论文中没有的信息。
    """

    // MARK: - Load Messages

    /// Loads all `ChatMessage` records for the given paper from SwiftData, sorted chronologically.
    func loadMessages(for paper: Paper, context: ModelContext) {
        self.paper = paper

        let arxivId = paper.arxivId
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.paper?.arxivId == arxivId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.relationshipKeyPathsForPrefetching = []

        do {
            messages = try context.fetch(descriptor)
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Send Message

    /// Creates a user `ChatMessage`, persists it, then streams the assistant reply.
    func sendMessage(context: ModelContext) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        guard let currentPaper = paper else {
            errorMessage = "未关联论文"
            return
        }

        // Configure LLM service lazily from UserDefaults on each send attempt.
        guard let service = resolvedLLMService() else {
            errorMessage = "请先在设置中配置 LLM 服务"
            return
        }
        llmService = service

        // 1. Persist and display the user message.
        let userMessage = ChatMessage(
            paper: currentPaper,
            role: "user",
            content: trimmed,
            timestamp: .now
        )
        context.insert(userMessage)
        messages.append(userMessage)
        inputText = ""

        try? context.save()

        // 2. Determine context strategy and build the system message.
        let strategy = ChatContextStrategy.resolve(paper: currentPaper, contextWindow: contextWindow)
        let systemContent = strategy.buildSystemContext(for: currentPaper, userQuery: trimmed)

        // 3. Build the full message array for the LLM.
        var llmMessages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemContent)
        ]

        // Append the conversation history (exclude the system message we just built).
        for msg in messages {
            guard msg.role == "user" || msg.role == "assistant" else { continue }
            llmMessages.append(LLMMessage(role: msg.role, content: msg.content))
        }

        // 4. Create a placeholder assistant message for streaming display.
        let assistantMessage = ChatMessage(
            paper: currentPaper,
            role: "assistant",
            content: "",
            timestamp: .now
        )
        context.insert(assistantMessage)
        messages.append(assistantMessage)

        isGenerating = true
        errorMessage = nil

        // 5. Stream the response and update the placeholder in real time.
        streamTask = Task {
            do {
                for try await chunk in service.completeStream(messages: llmMessages) {
                    guard !Task.isCancelled else { break }
                    assistantMessage.content += chunk
                    // Trigger view update by reassigning the last element.
                    if let idx = messages.lastIndex(where: { $0 === assistantMessage }) {
                        messages[idx] = assistantMessage
                    }
                }
            } catch is CancellationError {
                // Stream was intentionally stopped — partial content is already saved.
            } catch let error as LLMError {
                switch error {
                case .invalidURL:
                    errorMessage = "LLM 服务 URL 无效，请在设置中检查"
                case .badResponse(let code):
                    errorMessage = code == 401
                        ? "API Key 无效，请在设置中检查"
                        : "LLM 服务错误 (HTTP \(code))"
                case .invalidResponse:
                    errorMessage = "LLM 响应格式异常"
                case .missingAPIKey:
                    errorMessage = "API Key 未配置，请在设置中添加"
                }
            } catch {
                errorMessage = "生成失败: \(error.localizedDescription)"
            }

            // 6. Persist the (possibly partial) assistant message and update state.
            if assistantMessage.content.isEmpty {
                // Remove the placeholder if nothing was generated.
                context.delete(assistantMessage)
                messages.removeAll { $0 === assistantMessage }
            } else {
                try? context.save()
            }

            isGenerating = false
            streamTask = nil
        }
    }

    // MARK: - Stop Generation

    /// Cancels the in-flight stream task. Partial content is preserved in SwiftData.
    func stopGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
    }

    // MARK: - Private Helpers

    private func resolvedLLMService() -> LLMServiceProtocol? {
        guard
            let data = UserDefaults.standard.data(forKey: "llm_config"),
            let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: data),
            !config.baseURL.isEmpty
        else {
            return nil
        }
        return OpenAICompatibleService(config: config)
    }
}
