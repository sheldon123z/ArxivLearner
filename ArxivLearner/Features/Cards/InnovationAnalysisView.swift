import SwiftUI
import Observation

// MARK: - InnovationPoint

struct InnovationPoint: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let importance: Int // 1 (highest) to 3 (lowest)
}

// MARK: - InnovationAnalysisViewModel

@MainActor
@Observable
final class InnovationAnalysisViewModel {
    var rawResponse: String = ""
    var innovationPoints: [InnovationPoint] = []
    var isGenerating = false
    var errorMessage: String?

    private var llmService: LLMServiceProtocol?

    // MARK: Configuration

    func configure(config: LLMProviderConfig) {
        llmService = OpenAICompatibleService(config: config)
    }

    // MARK: Generation

    func generate(for paper: Paper) async {
        guard let service = llmService else {
            errorMessage = "请先配置 LLM 服务"
            return
        }

        isGenerating = true
        errorMessage = nil
        rawResponse = ""
        innovationPoints = []

        let paperContext = ContextBuilder.PaperContext(
            title: paper.title,
            abstractText: paper.abstractText,
            markdownContent: paper.markdownContent,
            fullText: nil
        )

        let messages: [LLMMessage] = [
            LLMMessage(
                role: "system",
                content: "请分析以下论文的创新点，按重要性排列。对每个创新点给出简短标题和详细说明。"
            ),
            LLMMessage(
                role: "user",
                content: ContextBuilder.buildContext(for: paperContext)
            ),
        ]

        do {
            for try await chunk in service.completeStream(messages: messages) {
                rawResponse += chunk
            }
            parseInnovationPoints(from: rawResponse)
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
            errorMessage = "生成失败: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func regenerate(for paper: Paper) async {
        rawResponse = ""
        innovationPoints = []
        await generate(for: paper)
    }

    // MARK: Private Parsing

    /// Parses the raw LLM response into structured InnovationPoint items.
    /// Supports numbered list format (1. / 2. / etc.) and heading-based formats.
    private func parseInnovationPoints(from text: String) {
        var points: [InnovationPoint] = []
        var importanceCounter = 1

        // Split on numbered list entries: "1.", "2.", etc.
        let pattern = #"(?m)^#{1,3}\s+(.+)$|^\d+[\.\)]\s+\*{0,2}(.+?)\*{0,2}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // Fallback: treat the whole response as a single point
            points.append(InnovationPoint(
                title: "创新点分析",
                detail: text,
                importance: 1
            ))
            innovationPoints = points
            return
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)

        if matches.isEmpty {
            // Fallback: split by double newlines and treat each block as a point
            let blocks = text.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for (index, block) in blocks.enumerated() {
                let lines = block.components(separatedBy: "\n")
                let title = lines.first ?? "创新点 \(index + 1)"
                let detail = lines.dropFirst().joined(separator: "\n")
                points.append(InnovationPoint(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    detail: detail.isEmpty ? block : detail.trimmingCharacters(in: .whitespacesAndNewlines),
                    importance: min(importanceCounter, 3)
                ))
                importanceCounter += 1
            }
        } else {
            // Extract title from match; then grab text until next match for the detail
            for (i, match) in matches.enumerated() {
                let headingRange = match.range(at: 1)
                let numberedRange = match.range(at: 2)

                var title = ""
                if headingRange.location != NSNotFound {
                    title = nsText.substring(with: headingRange)
                } else if numberedRange.location != NSNotFound {
                    title = nsText.substring(with: numberedRange)
                }

                // Detail: text between this match end and the next match start
                let detailStart = match.range.location + match.range.length
                let detailEnd: Int
                if i + 1 < matches.count {
                    detailEnd = matches[i + 1].range.location
                } else {
                    detailEnd = nsText.length
                }

                if detailEnd > detailStart {
                    let detailRange = NSRange(location: detailStart, length: detailEnd - detailStart)
                    let detail = nsText.substring(with: detailRange)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    points.append(InnovationPoint(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        detail: detail,
                        importance: min(importanceCounter, 3)
                    ))
                } else {
                    points.append(InnovationPoint(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        detail: "",
                        importance: min(importanceCounter, 3)
                    ))
                }
                importanceCounter += 1
            }
        }

        innovationPoints = points
    }
}

// MARK: - InnovationAnalysisView

struct InnovationAnalysisView: View {
    let paper: Paper

    @State private var viewModel = InnovationAnalysisViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGenerating && viewModel.innovationPoints.isEmpty {
                    generatingView
                } else if let error = viewModel.errorMessage, viewModel.innovationPoints.isEmpty {
                    errorView(message: error)
                } else if viewModel.innovationPoints.isEmpty && !viewModel.isGenerating {
                    emptyView
                } else {
                    pointsList
                }
            }
            .navigationTitle("创新点分析")
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
        .onAppear { startGeneration() }
    }

    // MARK: - Subviews

    private var generatingView: some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            ProgressView()
                .tint(AppTheme.primary)
                .scaleEffect(1.4)
            Text("正在分析创新点...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 8)
            // Show streaming text while generating
            if !viewModel.rawResponse.isEmpty {
                ScrollView {
                    Text(viewModel.rawResponse)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            Text("暂无创新点分析")
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

    private var pointsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                // Paper title header
                Text(paper.title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal)
                    .padding(.top, 4)

                ForEach(viewModel.innovationPoints) { point in
                    InnovationPointCard(point: point)
                        .padding(.horizontal)
                }

                // Show streaming indicator at bottom if still generating
                if viewModel.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppTheme.primary)
                        Text("继续生成中...")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData)
        else {
            viewModel.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }
        viewModel.configure(config: config)
        Task { await viewModel.generate(for: paper) }
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

// MARK: - InnovationPointCard

private struct InnovationPointCard: View {
    let point: InnovationPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ImportanceBadge(importance: point.importance)
                Text(point.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if !point.detail.isEmpty {
                Text(point.detail)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}

// MARK: - ImportanceBadge

private struct ImportanceBadge: View {
    let importance: Int

    private var label: String {
        switch importance {
        case 1: return "核心"
        case 2: return "重要"
        default: return "其他"
        }
    }

    private var color: Color {
        switch importance {
        case 1: return AppTheme.primary
        case 2: return AppTheme.secondary
        default: return AppTheme.textSecondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}
