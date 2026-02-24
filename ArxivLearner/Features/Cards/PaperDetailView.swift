import SwiftUI
import SwiftData

// MARK: - PaperDetailViewModel

@MainActor
@Observable
final class PaperDetailViewModel {
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var pdfLocalURL: URL?
    var showPDFReader: Bool = false
    var isConverting: Bool = false
    var conversionError: String?
    var conversionSuccess: Bool = false

    // MARK: PDF Download

    func downloadAndOpenPDF(paper: Paper) async {
        let arxivId = paper.arxivId

        if PDFCacheManager.shared.isDownloaded(arxivId: arxivId) {
            pdfLocalURL = PDFCacheManager.shared.localPath(for: arxivId)
            showPDFReader = true
            return
        }

        isDownloading = true
        downloadProgress = 0

        do {
            let url = try await PDFCacheManager.shared.download(
                from: paper.pdfURL,
                arxivId: arxivId,
                progress: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                    }
                }
            )
            pdfLocalURL = url
            paper.isDownloaded = true
            paper.pdfLocalPath = url.path
            isDownloading = false
            showPDFReader = true
        } catch {
            isDownloading = false
        }
    }

    // MARK: Doc2x Conversion

    func triggerDoc2xConversion(paper: Paper) async {
        guard let configData = UserDefaults.standard.data(forKey: "doc2x_config"),
              let apiKey = String(data: configData, encoding: .utf8),
              !apiKey.isEmpty
        else {
            conversionError = "请先在设置中配置 Doc2x API Key"
            return
        }

        guard paper.isDownloaded, let localPath = paper.pdfLocalPath else {
            conversionError = "请先下载 PDF 后再进行转换"
            return
        }

        guard let pdfData = try? Data(contentsOf: URL(fileURLWithPath: localPath)) else {
            conversionError = "无法读取 PDF 文件"
            return
        }

        isConverting = true
        conversionError = nil
        conversionSuccess = false
        paper.convertStatus = .converting

        let service = Doc2xService(apiKey: apiKey)

        do {
            let markdown = try await service.convert(pdfData: pdfData)
            paper.markdownContent = markdown
            paper.convertStatus = .completed
            paper.markdownConvertedAt = .now
            conversionSuccess = true
        } catch let error as Doc2xError {
            paper.convertStatus = .failed
            conversionError = error.localizedDescription
        } catch {
            paper.convertStatus = .failed
            conversionError = "转换失败: \(error.localizedDescription)"
        }

        isConverting = false
    }
}

// MARK: - PaperDetailView

struct PaperDetailView: View {
    let paper: Paper
    let modelContext: ModelContext

    @State private var viewModel = PaperDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    headerSection
                    Divider()
                    metadataSection
                    Divider()
                    abstractSection

                    if let markdown = paper.markdownContent, !markdown.isEmpty {
                        Divider()
                        markdownSection(content: markdown)
                    }

                    Divider()
                    readingStatsSection

                    Divider()
                    actionButtons
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("论文详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showPDFReader) {
                if let url = viewModel.pdfLocalURL {
                    PDFReaderView(title: paper.title, pdfURL: url, paper: paper)
                        .environment(\.modelContext, modelContext)
                }
            }
            .alert("转换成功", isPresented: $viewModel.conversionSuccess) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("论文已成功转换为 Markdown，现在可以在全文中查看。")
            }
            .alert("转换失败", isPresented: .constant(viewModel.conversionError != nil)) {
                Button("好的", role: .cancel) {
                    viewModel.conversionError = nil
                }
            } message: {
                Text(viewModel.conversionError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(paper.categories, id: \.self) { cat in
                        TagChip(
                            text: cat,
                            color: AppTheme.categoryColor(for: cat)
                        )
                    }
                }
            }

            // Title
            Text(paper.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("作者", systemImage: "person.2")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textSecondary)

            // All authors
            FlowLayout(spacing: 6) {
                ForEach(paper.authors, id: \.self) { author in
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.cardBackground)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: AppTheme.spacing) {
                Label(
                    paper.publishedDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                Label(paper.arxivId, systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var abstractSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("摘要", systemImage: "text.alignleft")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textSecondary)

            Text(paper.abstractText)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func markdownSection(content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("全文内容", systemImage: "doc.richtext")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if let convertedAt = paper.markdownConvertedAt {
                    Text("转换于 \(convertedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Text(content)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reading Stats Section

    private var readingStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("阅读统计", systemImage: "chart.bar.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textSecondary)

            let sessions = paper.readingSessions
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            let sessionCount = sessions.count
            let lastSession = sessions.sorted { $0.startTime > $1.startTime }.first

            HStack(spacing: AppTheme.spacing) {
                ReadingStatItem(
                    label: "总阅读时长",
                    value: formatDuration(totalDuration)
                )
                Divider().frame(height: 36)
                ReadingStatItem(
                    label: "阅读次数",
                    value: "\(sessionCount) 次"
                )
                Divider().frame(height: 36)
                ReadingStatItem(
                    label: "最后阅读",
                    value: lastSession.map {
                        $0.startTime.formatted(date: .abbreviated, time: .omitted)
                    } ?? "从未阅读"
                )
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: AppTheme.spacing) {
            // Open PDF button
            Button {
                Task { await viewModel.downloadAndOpenPDF(paper: paper) }
            } label: {
                HStack {
                    if viewModel.isDownloading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("下载中 \(Int(viewModel.downloadProgress * 100))%")
                    } else if paper.isDownloaded {
                        Image(systemName: "doc.richtext")
                        Text("打开 PDF")
                    } else {
                        Image(systemName: "arrow.down.circle")
                        Text("下载并打开 PDF")
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
            }
            .disabled(viewModel.isDownloading)

            // Doc2x conversion button
            Button {
                Task {
                    await viewModel.triggerDoc2xConversion(paper: paper)
                    try? modelContext.save()
                }
            } label: {
                HStack {
                    if viewModel.isConverting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppTheme.primary)
                        Text("转换中...")
                    } else if paper.convertStatus == .completed {
                        Image(systemName: "checkmark.circle")
                        Text("已转换为 Markdown")
                    } else if paper.convertStatus == .failed {
                        Image(systemName: "arrow.clockwise")
                        Text("重新转换 Markdown")
                    } else {
                        Image(systemName: "doc.plaintext")
                        Text("转换为 Markdown (doc2x)")
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(
                    paper.convertStatus == .completed
                        ? AppTheme.secondary
                        : AppTheme.primary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    (paper.convertStatus == .completed
                        ? AppTheme.secondary
                        : AppTheme.primary
                    ).opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
            }
            .disabled(viewModel.isConverting)
        }
    }
}

// MARK: - ReadingStatItem

private struct ReadingStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

