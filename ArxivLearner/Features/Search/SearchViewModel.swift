import Foundation
import Observation

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
    func search() async {
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
}
