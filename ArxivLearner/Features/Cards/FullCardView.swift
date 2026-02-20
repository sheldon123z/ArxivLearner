import SwiftUI
import SwiftData

// MARK: - FullCardView

struct FullCardView: View {
    let paper: ArxivPaperDTO
    let modelContext: ModelContext

    @Environment(\.dismiss) private var dismiss

    @State private var isFlipped = false
    @State private var isFavorite = false
    @State private var showPDFReader = false
    @State private var pdfLocalURL: URL?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var insightVM = InsightViewModel()

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Front side
                frontSide
                    .cardFlip(isFlipped: false)
                    .opacity(isFlipped ? 0 : 1)
                    .zIndex(isFlipped ? 0 : 1)

                // Back side
                backSide
                    .cardFlip(isFlipped: true)
                    .opacity(isFlipped ? 1 : 0)
                    .zIndex(isFlipped ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.6), value: isFlipped)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear { loadFavoriteState() }
        .sheet(isPresented: $showPDFReader) {
            if let url = pdfLocalURL {
                PDFReaderView(title: paper.title, pdfURL: url)
            }
        }
    }

    // MARK: - Front Side

    private var frontSide: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category tags + icons
            HStack {
                ForEach(paper.categories.prefix(3), id: \.self) { cat in
                    TagChip(
                        text: cat,
                        color: AppTheme.categoryColor(for: cat)
                    )
                }
                Spacer()
                Button {
                    isFavorite.toggle()
                    saveFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .red : AppTheme.textSecondary)
                        .font(.title3)
                }
                Button {} label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.title3)
                }
            }

            // Title
            Text(paper.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Authors
            Text(paper.authors.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(3)

            // Abstract (scrollable)
            ScrollView {
                Text(paper.abstractText)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(maxHeight: .infinity)

            // 4 action buttons
            HStack(spacing: 10) {
                actionButton(icon: "doc.richtext", label: "PDF") {
                    downloadAndOpenPDF()
                }
                actionButton(icon: "doc.plaintext", label: "转MD") {
                    // Markdown conversion - placeholder for future task
                }
                actionButton(icon: "sparkles", label: "见解") {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isFlipped = true
                    }
                    generateInsightIfNeeded()
                }
                actionButton(icon: "bubble.left.and.bubble.right", label: "问答") {
                    // Q&A - placeholder for future task
                }
            }

            // Date + flip button
            HStack {
                Text(paper.publishedDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isFlipped = true
                    }
                } label: {
                    Label("点击翻转", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .padding(AppTheme.cardPadding)
    }

    // MARK: - Back Side

    private var backSide: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.primary)
                    .font(.title3)
                Text("核心见解")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isFlipped = false
                    }
                } label: {
                    Label("翻转", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                }
            }

            // Insight content area (scrollable)
            ScrollView {
                insightContentView
            }
            .frame(maxHeight: .infinity)

            // 6 action buttons in 3 rows of 2
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    actionButton(icon: "lightbulb", label: "创新点") {
                        // Innovation points - placeholder
                    }
                    actionButton(icon: "function", label: "公式解析") {
                        // Formula parsing - placeholder
                    }
                }
                HStack(spacing: 10) {
                    actionButton(icon: "bubble.left.and.bubble.right", label: "论文问答") {
                        // Paper Q&A - placeholder
                    }
                    actionButton(icon: "character.book.closed", label: "全文翻译") {
                        // Full translation - placeholder
                    }
                }
                HStack(spacing: 10) {
                    actionButton(icon: "doc.richtext", label: "展开全文") {
                        downloadAndOpenPDF()
                    }
                    actionButton(icon: "arrow.clockwise", label: "重新生成") {
                        regenerateInsight()
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Insight Content View

    @ViewBuilder
    private var insightContentView: some View {
        if insightVM.isGenerating {
            VStack(spacing: AppTheme.spacing) {
                ProgressView()
                    .tint(AppTheme.primary)
                Text("正在生成见解...")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if let error = insightVM.errorMessage {
            VStack(spacing: AppTheme.spacing) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if insightVM.insight.isEmpty {
            VStack(spacing: AppTheme.spacing) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                Text("翻转后自动生成核心见解")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            Text(insightVM.insight)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Reusable Action Button

    private func actionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(AppTheme.primary)
            .background(AppTheme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - PDF Download & Open

    private func downloadAndOpenPDF() {
        let arxivId = paper.arxivId
        if PDFCacheManager.shared.isDownloaded(arxivId: arxivId) {
            pdfLocalURL = PDFCacheManager.shared.localPath(for: arxivId)
            showPDFReader = true
            return
        }

        isDownloading = true
        Task {
            do {
                let url = try await PDFCacheManager.shared.download(
                    from: paper.pdfURL.absoluteString,
                    arxivId: arxivId,
                    progress: { progress in
                        downloadProgress = progress
                    }
                )
                await MainActor.run {
                    pdfLocalURL = url
                    isDownloading = false
                    showPDFReader = true
                    // Update paper model
                    let swiftDataPaper = getOrCreatePaper()
                    swiftDataPaper.isDownloaded = true
                    swiftDataPaper.pdfLocalPath = url.path
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
            }
        }
    }

    // MARK: - Insight Generation

    private func generateInsightIfNeeded() {
        let swiftDataPaper = getOrCreatePaper()

        // If already has cached insight, load it directly
        if let cached = swiftDataPaper.llmInsight, !cached.isEmpty {
            insightVM.insight = cached
            return
        }

        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData) else {
            insightVM.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }

        insightVM.configure(config: config)

        Task {
            await insightVM.generateInsight(for: swiftDataPaper)
            try? modelContext.save()
        }
    }

    private func regenerateInsight() {
        let swiftDataPaper = getOrCreatePaper()

        guard let configData = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: configData) else {
            insightVM.errorMessage = "请先在设置中配置 LLM 服务"
            return
        }

        insightVM.configure(config: config)

        Task {
            await insightVM.regenerate(for: swiftDataPaper)
            try? modelContext.save()
        }
    }

    // MARK: - SwiftData Helpers

    @discardableResult
    private func getOrCreatePaper() -> Paper {
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let newPaper = Paper(
            arxivId: paper.arxivId,
            title: paper.title,
            authors: paper.authors,
            abstractText: paper.abstractText,
            categories: paper.categories,
            publishedDate: paper.publishedDate,
            pdfURL: paper.pdfURL.absoluteString
        )
        modelContext.insert(newPaper)
        try? modelContext.save()
        return newPaper
    }

    private func loadFavoriteState() {
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            isFavorite = existing.isFavorite
        }
    }

    private func saveFavorite() {
        let swiftDataPaper = getOrCreatePaper()
        swiftDataPaper.isFavorite = isFavorite
        try? modelContext.save()
    }
}
