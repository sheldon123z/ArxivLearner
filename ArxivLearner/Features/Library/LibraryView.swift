import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @Query private var allPapers: [Paper]
    @Query(sort: \Tag.createdAt, order: .reverse) private var allTags: [Tag]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Batch selection state
    @State private var isSelectionMode = false
    @State private var selectedPaperIds: Set<String> = []

    // MARK: - Tag filter state (Task 3.5)
    @State private var selectedFilterTags: Set<String> = []

    // MARK: - Sheet state
    @State private var showTagSelection = false
    @State private var showTagRemoval = false
    @State private var showBatchConvert = false

    var filteredPapers: [Paper] {
        let byFilter: [Paper]
        switch viewModel.selectedFilter {
        case .favorites:
            byFilter = allPapers.filter { $0.isFavorite }
        case .downloaded:
            byFilter = allPapers.filter { $0.isDownloaded }
        case .viewed:
            byFilter = allPapers.filter { $0.viewedAt != nil }.sorted {
                ($0.viewedAt ?? .distantPast) > ($1.viewedAt ?? .distantPast)
            }
        case .all:
            byFilter = allPapers
        }

        guard !selectedFilterTags.isEmpty else { return byFilter }
        return byFilter.filter { paper in
            let paperTagNames = Set(paper.tagItems.map { $0.name })
            return selectedFilterTags.isSubset(of: paperTagNames)
        }
    }

    var selectedPapers: [Paper] {
        filteredPapers.filter { selectedPaperIds.contains($0.arxivId) }
    }

    var downloadedSelectedPapers: [Paper] {
        selectedPapers.filter { $0.isDownloaded }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                Picker("筛选", selection: $viewModel.selectedFilter) {
                    ForEach(LibraryViewModel.Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tag filter chips (Task 3.5)
                if !allTags.isEmpty {
                    tagFilterBar
                }

                // Batch action bar (Task 3.4)
                if isSelectionMode {
                    batchActionBar
                }

                // Paper list
                if filteredPapers.isEmpty {
                    ContentUnavailableView(
                        "暂无论文",
                        systemImage: "book.closed",
                        description: Text(emptyDescription)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.spacing) {
                            ForEach(filteredPapers, id: \.arxivId) { paper in
                                LibraryCardView(
                                    paper: paper,
                                    modelContext: modelContext,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedPaperIds.contains(paper.arxivId)
                                ) {
                                    toggleSelection(paper.arxivId)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("文库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelectionMode ? "完成" : "选择") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedPaperIds.removeAll() }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.cleanupOldViewedPapers(modelContext: modelContext)
            }
            .sheet(isPresented: $showTagSelection) {
                TagSelectionSheet(papers: selectedPapers)
            }
            .sheet(isPresented: $showTagRemoval) {
                TagRemovalSheet(papers: selectedPapers)
            }
            .sheet(isPresented: $showBatchConvert) {
                BatchConvertProgressView(papers: downloadedSelectedPapers)
            }
        }
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.name) { tag in
                    let isActive = selectedFilterTags.contains(tag.name)
                    TagFilterChip(tag: tag, isActive: isActive) {
                        if isActive {
                            selectedFilterTags.remove(tag.name)
                        } else {
                            selectedFilterTags.insert(tag.name)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppTheme.cardBackground.opacity(0.5))
    }

    // MARK: - Batch Action Bar

    private var batchActionBar: some View {
        HStack(spacing: 10) {
            Text(selectedPaperIds.isEmpty ? "未选中" : "已选 \(selectedPaperIds.count) 篇")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                showTagSelection = true
            } label: {
                Label("添加标签", systemImage: "tag.badge.plus")
                    .font(.caption)
            }
            .disabled(selectedPaperIds.isEmpty)
            .buttonStyle(.bordered)
            .tint(AppTheme.primary)

            Button {
                showTagRemoval = true
            } label: {
                Label("移除标签", systemImage: "tag.slash")
                    .font(.caption)
            }
            .disabled(selectedPaperIds.isEmpty)
            .buttonStyle(.bordered)
            .tint(.red)

            if !downloadedSelectedPapers.isEmpty {
                Button {
                    showBatchConvert = true
                } label: {
                    Label("批量转MD", systemImage: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceElevated)
    }

    // MARK: - Helpers

    private func toggleSelection(_ arxivId: String) {
        if selectedPaperIds.contains(arxivId) {
            selectedPaperIds.remove(arxivId)
        } else {
            selectedPaperIds.insert(arxivId)
        }
    }

    private var emptyDescription: String {
        switch viewModel.selectedFilter {
        case .favorites:
            return "搜索并收藏论文后会在这里显示"
        case .downloaded:
            return "下载 PDF 后会在这里显示"
        case .viewed:
            return "左滑跳过的论文会在这里显示"
        case .all:
            return "暂无保存的论文"
        }
    }
}

// MARK: - TagFilterChip

private struct TagFilterChip: View {
    let tag: Tag
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color(hex: tag.colorHex).opacity(0.2) : AppTheme.cardBackground)
            .foregroundStyle(isActive ? Color(hex: tag.colorHex) : AppTheme.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color(hex: tag.colorHex) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LibraryCardView

struct LibraryCardView: View {
    let paper: Paper
    let modelContext: ModelContext
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionTap: (() -> Void)? = nil

    @State private var showFullCard = false

    init(paper: Paper, modelContext: ModelContext) {
        self.paper = paper
        self.modelContext = modelContext
    }

    init(
        paper: Paper,
        modelContext: ModelContext,
        isSelectionMode: Bool,
        isSelected: Bool,
        onSelectionTap: @escaping () -> Void
    ) {
        self.paper = paper
        self.modelContext = modelContext
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onSelectionTap = onSelectionTap
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.primary : .gray)
                    .font(.title3)
                    .padding(.top, 14)
            }

            cardContent
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onSelectionTap?()
            } else {
                showFullCard = true
            }
        }
        .fullScreenCover(isPresented: $showFullCard) {
            FullCardView(paper: paper.toDTO, modelContext: modelContext)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ForEach(paper.categories.prefix(2), id: \.self) { cat in
                    TagChip(text: cat, color: AppTheme.categoryColor(for: cat))
                }

                Spacer()

                if paper.convertStatus == .completed {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }

                if paper.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Image(systemName: paper.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(paper.isFavorite ? .red : AppTheme.textSecondary)
            }

            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            HStack {
                Text(paper.authors.first ?? "")
                if paper.authors.count > 1 { Text("et al.") }
                Text("·")
                Text(paper.publishedDate, format: .dateTime.year().month())
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            Text(paper.abstractText)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            // User-defined tag chips
            if !paper.tagItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(paper.tagItems, id: \.name) { tag in
                            TagChip(text: tag.name, color: Color(hex: tag.colorHex))
                        }
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(isSelected ? AppTheme.primary.opacity(0.08) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: .black.opacity(0.1), radius: AppTheme.cardShadowRadius, x: 0, y: 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Paper.self, inMemory: true)
}
