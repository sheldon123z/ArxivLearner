import Foundation

// MARK: - ContextBuilder

/// Builds LLM context strings from paper content, applying a priority strategy:
/// markdown > fullText > abstract.
enum ContextBuilder {

    // MARK: - PaperContext

    struct PaperContext {
        /// The paper title.
        let title: String
        /// The paper abstract (always required as a fallback).
        let abstractText: String
        /// Parsed Markdown representation of the paper body (highest priority).
        let markdownContent: String?
        /// Plain-text full content of the paper (used when markdown is unavailable).
        let fullText: String?
    }

    // MARK: - Public API

    /// Returns the best available content string for the given paper context.
    /// Priority order: markdownContent > fullText > abstractText.
    static func buildContext(for paper: PaperContext) -> String {
        let body: String
        if let markdown = paper.markdownContent, !markdown.isEmpty {
            body = markdown
        } else if let full = paper.fullText, !full.isEmpty {
            body = full
        } else {
            body = paper.abstractText
        }

        return """
        标题: \(paper.title)

        \(body)
        """
    }

    /// Returns the system prompt used for Chinese academic paper analysis.
    static func insightSystemPrompt() -> String {
        """
        你是一位专业的学术论文助手，擅长分析和解读人工智能与机器学习领域的研究论文。
        请使用中文回答所有问题，语言简洁清晰，适合研究人员和学生阅读。
        在分析论文时，请重点关注：研究问题、核心方法、实验结果以及对领域的贡献。
        如遇到专业术语，可保留英文原文并附上中文解释。
        """
    }

    // MARK: - Template-Based Message Building

    /// Builds an array of `LLMMessage` values from a `PromptTemplate` and a `Paper`.
    ///
    /// The method resolves all `{{variable}}` placeholders in both the template's
    /// `systemPrompt` and `userPromptTemplate` using `PromptVariableEngine`, then
    /// assembles the messages in the order expected by the chat-completion API:
    /// 1. A `system` role message containing the resolved system prompt.
    /// 2. A `user` role message containing the resolved user prompt template.
    /// 3. An optional additional `user` role message for free-form chat input.
    ///
    /// - Parameters:
    ///   - template:     The `PromptTemplate` whose prompts will be resolved.
    ///   - paper:        The `Paper` whose data populates the template variables.
    ///   - userMessage:  An optional free-form message appended after the resolved
    ///                   user prompt template (e.g. a follow-up question in a chat session).
    ///   - selectedText: Text the user has highlighted in the reader, passed through
    ///                   to `PromptVariableEngine` for `{{selected_text}}` substitution.
    /// - Returns: An ordered array of `LLMMessage` values ready for the LLM service.
    static func buildMessages(
        template: PromptTemplate,
        paper: Paper,
        userMessage: String? = nil,
        selectedText: String? = nil
    ) -> [LLMMessage] {
        let resolvedSystem = PromptVariableEngine.resolve(
            template: template.systemPrompt,
            paper: paper,
            selectedText: selectedText
        )

        let resolvedUserPrompt = PromptVariableEngine.resolve(
            template: template.userPromptTemplate,
            paper: paper,
            selectedText: selectedText
        )

        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: resolvedSystem),
            LLMMessage(role: "user", content: resolvedUserPrompt)
        ]

        if let extra = userMessage, !extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(LLMMessage(role: "user", content: extra))
        }

        return messages
    }
}
