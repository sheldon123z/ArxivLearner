import SwiftUI
import Observation

// MARK: - ExtractedFormula

struct ExtractedFormula: Identifiable {
    let id = UUID()
    let latex: String
    let isBlock: Bool // true for $$...$$, false for $...$
    var explanation: String = ""
}

// MARK: - FormulaAnalysisViewModel

@MainActor
@Observable
final class FormulaAnalysisViewModel {
    var formulas: [ExtractedFormula] = []
    var rawResponse: String = ""
    var isGenerating = false
    var errorMessage: String?
    var hasFormulas: Bool = false

    private var llmService: LLMServiceProtocol?

    // MARK: Configuration

    func configure(config: LLMProviderConfig) {
        llmService = OpenAICompatibleService(config: config)
    }

    // MARK: Formula Extraction

    /// Extracts LaTeX formulas from markdown content.
    /// Block formulas ($$...$$) take priority; inline ($...$) are also included.
    func extractFormulas(from text: String) {
        var results: [ExtractedFormula] = []

        // Extract block formulas: $$...$$ (possibly multiline)
        let blockPattern = #"\$\$[\s\S]+?\$\$"#
        if let blockRegex = try? NSRegularExpression(pattern: blockPattern) {
            let nsText = text as NSString
            let matches = blockRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let raw = nsText.substring(with: match.range)
                let latex = raw
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "$$", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !latex.isEmpty {
                    results.append(ExtractedFormula(latex: latex, isBlock: true))
                }
            }
        }

        // Extract inline formulas: $...$ (excluding $$ already captured)
        // Use negative lookbehind/lookahead to skip $$
        let inlinePattern = #"(?<!\$)\$(?!\$)([^$\n]+?)(?<!\$)\$(?!\$)"#
        if let inlineRegex = try? NSRegularExpression(pattern: inlinePattern) {
            let nsText = text as NSString
            let matches = inlineRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            // Limit to first 15 unique inline formulas to avoid overload
            var seen = Set<String>()
            for match in matches {
                if match.numberOfRanges > 1 {
                    let latexRange = match.range(at: 1)
                    if latexRange.location != NSNotFound {
                        let latex = nsText.substring(with: latexRange)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !latex.isEmpty && !seen.contains(latex) && results.count < 20 {
                            seen.insert(latex)
                            results.append(ExtractedFormula(latex: latex, isBlock: false))
                        }
                    }
                }
            }
        }

        formulas = results
        hasFormulas = !results.isEmpty
    }

    // MARK: LLM Analysis

    func analyze(for paper: Paper) async {
        guard let service = llmService else {
            errorMessage = "请先配置 LLM 服务"
            return
        }

        isGenerating = true
        errorMessage = nil
        rawResponse = ""

        let content = paper.markdownContent ?? paper.abstractText
        extractFormulas(from: content)

        let formulaList = formulas.prefix(10).enumerated().map { (i, f) in
            "\(i + 1). \(f.isBlock ? "（块级公式）" : "（行内公式）")\n$$\(f.latex)$$"
        }.joined(separator: "\n\n")

        let userContent: String
        if formulas.isEmpty {
            userContent = """
            标题: \(paper.title)

            摘要: \(paper.abstractText)

            （未发现明显的 LaTeX 公式，请根据摘要提取和解析该论文可能涉及的关键数学概念和公式。）
            """
        } else {
            userContent = """
            标题: \(paper.title)

            从论文中提取到的关键公式：

            \(formulaList)
            """
        }

        let messages: [LLMMessage] = [
            LLMMessage(
                role: "system",
                content: "请提取并解析以下论文中的关键数学公式，用通俗的语言解释每个公式的含义和作用。"
            ),
            LLMMessage(role: "user", content: userContent),
        ]

        do {
            for try await chunk in service.completeStream(messages: messages) {
                rawResponse += chunk
            }
        } catch let error as LLMError {
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
        } catch {
            errorMessage = "分析失败: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func regenerate(for paper: Paper) async {
        rawResponse = ""
        formulas = []
        await analyze(for: paper)
    }
}

// MARK: - FormulaAnalysisView

struct FormulaAnalysisView: View {
    let paper: Paper

    @State private var viewModel = FormulaAnalysisViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGenerating && viewModel.rawResponse.isEmpty {
                    generatingView
                } else if let error = viewModel.errorMessage, viewModel.rawResponse.isEmpty {
                    errorView(message: error)
                } else if !viewModel.rawResponse.isEmpty || viewModel.isGenerating {
                    contentView
                } else {
                    emptyView
                }
            }
            .navigationTitle("公式解析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await regenerate() }
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.isGenerating)
                }
            }
        }
        .onAppear { startAnalysis() }
    }

    // MARK: - Subviews

    private var generatingView: some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            ProgressView()
                .tint(AppTheme.primary)
                .scaleEffect(1.4)
            Text("正在分析公式...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            Image(systemName: "function")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            Text("暂无公式分析")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                Task { await regenerate() }
            } label: {
                Text("开始分析")
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

    private func errorView(message: String) -> some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("分析失败")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await regenerate() }
            } label: {
                Text("重试")
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

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                // Extracted formulas summary
                if !viewModel.formulas.isEmpty {
                    formulaSummarySection
                } else {
                    noFormulasBanner
                }

                Divider()
                    .padding(.horizontal)

                // LLM explanation
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI 解析", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primary)
                        .padding(.horizontal)

                    Text(viewModel.rawResponse)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal)

                    if viewModel.isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppTheme.primary)
                            Text("正在生成...")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .padding(.vertical)
        }
    }

    private var formulaSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("发现 \(viewModel.formulas.count) 个公式", systemImage: "function")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.formulas.prefix(10)) { formula in
                        FormulaChip(formula: formula)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var noFormulasBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppTheme.secondary)
            Text("未检测到 LaTeX 公式，已根据摘要进行分析")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .background(AppTheme.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func startAnalysis() {
        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData)
        else {
            viewModel.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }
        viewModel.configure(config: config)
        Task { await viewModel.analyze(for: paper) }
    }

    private func regenerate() async {
        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData)
        else {
            viewModel.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }
        viewModel.configure(config: config)
        await viewModel.regenerate(for: paper)
    }
}

// MARK: - FormulaChip

private struct FormulaChip: View {
    let formula: ExtractedFormula

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: formula.isBlock ? "square.and.pencil" : "character.cursor.ibeam")
                .font(.caption2)
                .foregroundStyle(AppTheme.primary)
            Text(formula.latex.prefix(30) + (formula.latex.count > 30 ? "..." : ""))
                .font(.caption.monospaced())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
