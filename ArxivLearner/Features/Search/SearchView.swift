import SwiftUI
import SwiftData

// MARK: - SearchView

struct SearchView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SearchViewModel()
    @State private var showFilters = false
    @State private var isSwipeMode: Bool = false
    @State private var showSaveSearch = false
    @State private var showSavedSearchList = false

    @Query(sort: \SearchHistory.timestamp, order: .reverse) private var searchHistories: [SearchHistory]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if showFilters {
                    filterBar
                }

                if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 空搜索状态：显示历史和推荐主题
                    emptyQueryContent
                } else if isSwipeMode {
                    swipeModeContent
                } else {
                    resultsList
                }
            }
            .background(AppTheme.background)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 保存搜索按钮（仅有搜索词时显示）
                    if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            showSaveSearch = true
                        } label: {
                            Image(systemName: "bookmark")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    // 已保存的搜索入口
                    NavigationLink {
                        SavedSearchListView { saved in
                            viewModel.query = saved.query
                            viewModel.selectedCategory = saved.filterCategory
                            Task { await viewModel.search(modelContext: modelContext) }
                        }
                        .environment(\.modelContext, modelContext)
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.primary)
                    }

                    // 列表/滑动模式切换按钮（仅有搜索结果时显示）
                    if !viewModel.papers.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSwipeMode.toggle()
                            }
                        } label: {
                            Image(systemName: isSwipeMode ? "list.bullet" : "rectangle.stack")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedSortBy) {
                guard !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await viewModel.search(modelContext: modelContext) }
            }
            .onChange(of: viewModel.selectedCategory) {
                guard !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { await viewModel.search(modelContext: modelContext) }
            }
            .sheet(isPresented: $showSaveSearch) {
                SaveSearchSheet(
                    query: viewModel.query,
                    category: viewModel.selectedCategory
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppTheme.spacing) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("搜索论文...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search(modelContext: modelContext) }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.papers = []
                        isSwipeMode = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFilters.toggle()
                }
            } label: {
                Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(showFilters ? AppTheme.primary : AppTheme.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: AppTheme.spacing) {
            // Category picker
            Menu {
                Button("全部分类") {
                    viewModel.selectedCategory = nil
                }
                Divider()
                ForEach(viewModel.availableCategories, id: \.self) { category in
                    Button(category) {
                        viewModel.selectedCategory = category
                    }
                }
            } label: {
                Label(
                    viewModel.selectedCategory ?? "分类",
                    systemImage: "folder"
                )
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    viewModel.selectedCategory != nil
                        ? AppTheme.primary.opacity(0.15)
                        : AppTheme.cardBackground
                )
                .foregroundStyle(
                    viewModel.selectedCategory != nil
                        ? AppTheme.primary
                        : AppTheme.textPrimary
                )
                .clipShape(Capsule())
            }

            // Sort picker
            Menu {
                Button("相关性") {
                    viewModel.selectedSortBy = .relevance
                }
                Button("最近更新") {
                    viewModel.selectedSortBy = .lastUpdatedDate
                }
                Button("提交日期") {
                    viewModel.selectedSortBy = .submittedDate
                }
            } label: {
                Label(
                    sortByLabel,
                    systemImage: "arrow.up.arrow.down"
                )
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.cardBackground)
                .foregroundStyle(AppTheme.textPrimary)
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Empty Query Content (历史 + 推荐主题)

    private var emptyQueryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 推荐主题
                let topics = viewModel.extractRecommendedTopics(from: Array(searchHistories))
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("推荐主题")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(topics, id: \.self) { topic in
                                    Button {
                                        viewModel.query = topic
                                        Task { await viewModel.search(modelContext: modelContext) }
                                    } label: {
                                        Text(topic)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(AppTheme.primary.opacity(0.12))
                                            .foregroundStyle(AppTheme.primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // 搜索历史
                if !searchHistories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("搜索历史")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button("清除") {
                                clearAllHistory()
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal)

                        ForEach(searchHistories.prefix(20)) { history in
                            SearchHistoryRow(history: history) {
                                viewModel.query = history.query
                                if let cat = history.filterCategory {
                                    viewModel.selectedCategory = cat
                                }
                                Task { await viewModel.search(modelContext: modelContext) }
                            } onDelete: {
                                modelContext.delete(history)
                                try? modelContext.save()
                            }
                        }
                    }
                }

                if searchHistories.isEmpty && viewModel.extractRecommendedTopics(from: []).isEmpty {
                    Spacer().frame(height: 40)
                    emptyStateView
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Swipe Mode Content

    private var swipeModeContent: some View {
        Group {
            if viewModel.isLoading && viewModel.papers.isEmpty {
                Spacer()
                LoadingOverlay(message: "正在搜索...")
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.papers.isEmpty {
                Spacer()
                errorView(message: error)
                Spacer()
            } else {
                SwipeCardView(
                    papers: viewModel.papers,
                    modelContext: modelContext
                ) {
                    // 卡片用尽时尝试加载更多
                    Task { await viewModel.loadMore() }
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        Group {
            if viewModel.isLoading && viewModel.papers.isEmpty {
                Spacer()
                LoadingOverlay(message: "正在搜索...")
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.papers.isEmpty {
                Spacer()
                errorView(message: error)
                Spacer()
            } else if viewModel.papers.isEmpty {
                Spacer()
                emptyStateView
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.spacing) {
                        ForEach(viewModel.papers, id: \.arxivId) { paper in
                            CompactCardView(paper: paper, modelContext: modelContext)
                        }

                        // Load more trigger
                        if viewModel.hasMoreResults {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await viewModel.loadMore() }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))

            Text("搜索 arXiv 论文")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("输入关键词开始搜索")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.accent)

            Text("搜索出错")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.search(modelContext: modelContext) }
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
        }
    }

    // MARK: - Helpers

    private var sortByLabel: String {
        switch viewModel.selectedSortBy {
        case .relevance:
            return "相关性"
        case .lastUpdatedDate:
            return "最近更新"
        case .submittedDate:
            return "提交日期"
        }
    }

    private func clearAllHistory() {
        for history in searchHistories {
            modelContext.delete(history)
        }
        try? modelContext.save()
    }
}

// MARK: - SearchHistoryRow

struct SearchHistoryRow: View {

    let history: SearchHistory
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text(history.query)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(history.timestamp, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
