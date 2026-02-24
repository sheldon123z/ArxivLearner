import Foundation
import Observation
import SwiftData

// MARK: - SearchViewModel

@Observable
final class SearchViewModel {

    // MARK: Published State

    var query: String = ""
    var selectedCategory: String?
    var selectedDateRange: ArxivDateRange?
    var selectedSortBy: ArxivSortBy = .relevance
    var papers: [ArxivPaperDTO] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var hasMoreResults: Bool = false

    // MARK: Pagination

    private var currentPage: Int = 0
    private let pageSize: Int = 20

    // MARK: Dependencies

    private let apiService: ArxivAPIService

    // MARK: Init

    init(apiService: ArxivAPIService = ArxivAPIService()) {
        self.apiService = apiService
    }

    // MARK: Computed Properties

    /// Common arXiv categories for the filter picker.
    var availableCategories: [String] {
        [
            "cs.AI",
            "cs.LG",
            "cs.CV",
            "cs.CL",
            "cs.RO",
            "cs.NE",
            "cs.IR",
            "cs.SE",
            "stat.ML",
            "math.OC",
            "eess.SP",
            "physics.comp-ph"
        ]
    }

    // MARK: Public Methods

    /// Performs a new search, replacing any existing results.
    @MainActor
    func search(modelContext: ModelContext? = nil) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        currentPage = 0
        isLoading = true
        errorMessage = nil

        let params = ArxivSearchParams(
            query: trimmedQuery,
            category: selectedCategory,
            dateRange: selectedDateRange,
            sortBy: selectedSortBy,
            start: 0,
            maxResults: pageSize
        )

        do {
            let results = try await apiService.search(params: params)
            papers = results
            hasMoreResults = results.count >= pageSize

            // 保存搜索历史
            if let ctx = modelContext {
                saveSearchHistory(query: trimmedQuery, modelContext: ctx)
            }
        } catch {
            errorMessage = error.localizedDescription
            papers = []
            hasMoreResults = false
        }

        isLoading = false
    }

    /// Loads the next page of results and appends them to the existing list.
    @MainActor
    func loadMore() async {
        guard !isLoading, hasMoreResults else { return }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        currentPage += 1
        isLoading = true

        let params = ArxivSearchParams(
            query: trimmedQuery,
            category: selectedCategory,
            dateRange: selectedDateRange,
            sortBy: selectedSortBy,
            start: currentPage * pageSize,
            maxResults: pageSize
        )

        do {
            let results = try await apiService.search(params: params)
            papers.append(contentsOf: results)
            hasMoreResults = results.count >= pageSize
        } catch {
            errorMessage = error.localizedDescription
            // Revert page increment on failure so retry uses the same offset.
            currentPage -= 1
        }

        isLoading = false
    }

    // MARK: - Search History

    private func saveSearchHistory(query: String, modelContext: ModelContext) {
        // 避免重复保存相同查询（检查最近的历史）
        let descriptor = FetchDescriptor<SearchHistory>(
            predicate: #Predicate { $0.query == query },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            // 如果同一查询在5分钟内已存在，不重复保存
            if Date.now.timeIntervalSince(existing.timestamp) < 300 {
                return
            }
        }

        let history = SearchHistory(
            query: query,
            filterCategory: selectedCategory,
            timestamp: .now
        )
        modelContext.insert(history)
        try? modelContext.save()
    }

    // MARK: - Recommended Topics

    /// 从搜索历史中提取高频关键词，返回前 N 个推荐主题
    func extractRecommendedTopics(from histories: [SearchHistory], limit: Int = 8) -> [String] {
        var wordCount: [String: Int] = [:]
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "in", "of", "for", "to", "with", "on"]

        for history in histories {
            let words = history.query
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
            for word in words {
                wordCount[word, default: 0] += 1
            }
        }

        return wordCount
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
}
