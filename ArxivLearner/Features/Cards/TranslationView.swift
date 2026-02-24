import SwiftUI
import Observation

// MARK: - TranslatedParagraph

struct TranslatedParagraph: Identifiable {
    let id = UUID()
    let original: String
    var translation: String = ""
    var isTranslating: Bool = false
    var isTranslated: Bool = false
}

// MARK: - TranslationViewModel

@MainActor
@Observable
final class TranslationViewModel {
    var paragraphs: [TranslatedParagraph] = []
    var translatedCount: Int = 0
    var isTranslating: Bool = false
    var errorMessage: String?
    var displayMode: DisplayMode = .alternating

    enum DisplayMode {
        case alternating
        case sideBySide
    }

    private var llmService: LLMServiceProtocol?
    private var translationTask: Task<Void, Never>?

    // MARK: Configuration

    func configure(config: LLMProviderConfig) {
        llmService = OpenAICompatibleService(config: config)
    }

    // MARK: Content Splitting

    func prepareContent(from paper: Paper) {
        let source = paper.markdownContent ?? paper.abstractText
        let raw = source
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 } // Skip very short lines

        paragraphs = raw.map { TranslatedParagraph(original: $0) }
        translatedCount = 0
    }

    // MARK: Translation

    func startTranslation() async {
        guard let service = llmService else {
            errorMessage = "请先配置 LLM 服务"
            return
        }

        guard !paragraphs.isEmpty else { return }
        isTranslating = true
        errorMessage = nil

        for index in paragraphs.indices {
            guard isTranslating else { break }
            guard !paragraphs[index].isTranslated else {
                continue
            }

            paragraphs[index].isTranslating = true
            paragraphs[index].translation = ""

            let original = paragraphs[index].original

            let messages: [LLMMessage] = [
                LLMMessage(
                    role: "system",
                    content: "你是一位专业的学术翻译助手，请将以下英文学术文本翻译成流畅、准确的中文。保留专业术语，直接输出翻译结果，不要添加任何额外说明。"
                ),
                LLMMessage(role: "user", content: original),
            ]

            do {
                for try await chunk in service.completeStream(messages: messages) {
                    paragraphs[index].translation += chunk
                }
                paragraphs[index].isTranslating = false
                paragraphs[index].isTranslated = true
                translatedCount += 1
            } catch let error as LLMError {
                paragraphs[index].isTranslating = false
                switch error {
                case .invalidURL:
                    errorMessage = "LLM 服务 URL 无效，请在设置中检查"
                case .badResponse(let code):
                    if code == 401 {
                        errorMessage = "API Key 无效，请在设置中检查"
                    } else {
                        errorMessage = "LLM 服务错误 (HTTP \(code))"
                    }
                case .invalidResponse:
                    errorMessage = "LLM 响应格式异常"
                case .missingAPIKey:
                    errorMessage = "API Key 未配置，请在设置中添加"
                }
                isTranslating = false
                return
            } catch {
                paragraphs[index].isTranslating = false
                if isTranslating {
                    errorMessage = "翻译失败: \(error.localizedDescription)"
                }
                isTranslating = false
                return
            }
        }

        isTranslating = false
    }

    func stopTranslation() {
        isTranslating = false
    }

    func resetAndRetranslate() {
        stopTranslation()
        for index in paragraphs.indices {
            paragraphs[index].translation = ""
            paragraphs[index].isTranslated = false
            paragraphs[index].isTranslating = false
        }
        translatedCount = 0
        errorMessage = nil
    }
}

// MARK: - TranslationView

struct TranslationView: View {
    let paper: Paper

    @State private var viewModel = TranslationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                contentArea
            }
            .navigationTitle("全文翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        viewModel.stopTranslation()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        displayModeToggle
                        translationControlButton
                    }
                }
            }
        }
        .onAppear { setup() }
        .onDisappear { viewModel.stopTranslation() }
    }

    // MARK: - Subviews

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("已翻译 \(viewModel.translatedCount) / \(viewModel.paragraphs.count) 段")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if viewModel.isTranslating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(AppTheme.primary)
                        Text("翻译中")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .padding(.horizontal)

            if !viewModel.paragraphs.isEmpty {
                ProgressView(
                    value: Double(viewModel.translatedCount),
                    total: Double(viewModel.paragraphs.count)
                )
                .tint(AppTheme.primary)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
    }

    private var contentArea: some View {
        Group {
            if viewModel.paragraphs.isEmpty {
                Spacer()
                Text("正在准备内容...")
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                paragraphList
            }
        }
    }

    private var paragraphList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.spacing) {
                ForEach(viewModel.paragraphs) { paragraph in
                    ParagraphCard(paragraph: paragraph)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("翻译中断")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task {
                    viewModel.errorMessage = nil
                    await viewModel.startTranslation()
                }
            } label: {
                Text("继续翻译")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private var displayModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.displayMode = viewModel.displayMode == .alternating
                    ? .sideBySide
                    : .alternating
            }
        } label: {
            Image(systemName: viewModel.displayMode == .alternating
                ? "rectangle.split.2x1"
                : "text.alignleft"
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.primary)
        }
    }

    private var translationControlButton: some View {
        Group {
            if viewModel.isTranslating {
                Button {
                    viewModel.stopTranslation()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } else {
                Button {
                    viewModel.resetAndRetranslate()
                    Task { await viewModel.startTranslation() }
                } label: {
                    Label("重新翻译", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData)
        else {
            viewModel.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }
        viewModel.configure(config: config)
        viewModel.prepareContent(from: paper)
        Task { await viewModel.startTranslation() }
    }
}

// MARK: - ParagraphCard

private struct ParagraphCard: View {
    let paragraph: TranslatedParagraph

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original text
            VStack(alignment: .leading, spacing: 4) {
                Label("原文", systemImage: "doc.text")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(paragraph.original)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Translation
            VStack(alignment: .leading, spacing: 4) {
                Label("译文", systemImage: "character.book.closed.zh")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)

                if paragraph.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(AppTheme.primary)
                        if !paragraph.translation.isEmpty {
                            Text(paragraph.translation)
                                .font(.body)
                                .foregroundStyle(AppTheme.textPrimary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("正在翻译...")
                                .font(.body)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } else if paragraph.isTranslated {
                    Text(paragraph.translation)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("等待翻译")
                        .font(.body)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                        .italic()
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}
