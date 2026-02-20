import XCTest
@testable import ArxivLearner

// MARK: - SearchViewModelTests

final class SearchViewModelTests: XCTestCase {

    private var viewModel: SearchViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - testInitialState

    /// Verify the view model starts with empty papers, not loading, and an empty query.
    func testInitialState() {
        XCTAssertTrue(
            viewModel.papers.isEmpty,
            "papers should be empty on init"
        )
        XCTAssertFalse(
            viewModel.isLoading,
            "isLoading should be false on init"
        )
        XCTAssertEqual(
            viewModel.query, "",
            "query should be an empty string on init"
        )
        XCTAssertNil(
            viewModel.errorMessage,
            "errorMessage should be nil on init"
        )
        XCTAssertNil(
            viewModel.selectedCategory,
            "selectedCategory should be nil on init"
        )
        XCTAssertNil(
            viewModel.selectedDateRange,
            "selectedDateRange should be nil on init"
        )
        XCTAssertEqual(
            viewModel.selectedSortBy, .relevance,
            "selectedSortBy should default to .relevance"
        )
        XCTAssertFalse(
            viewModel.hasMoreResults,
            "hasMoreResults should be false on init"
        )
    }

    // MARK: - testSearchQueryNotEmpty

    /// A whitespace-only query should not trigger a search; papers should remain empty.
    @MainActor
    func testSearchQueryNotEmpty() async {
        viewModel.query = "   "

        await viewModel.search()

        XCTAssertTrue(
            viewModel.papers.isEmpty,
            "papers should remain empty when query is only whitespace"
        )
        XCTAssertFalse(
            viewModel.isLoading,
            "isLoading should remain false when search is not triggered"
        )
        XCTAssertNil(
            viewModel.errorMessage,
            "errorMessage should remain nil when search is not triggered"
        )
    }

    // MARK: - testAvailableCategories

    /// Verify that availableCategories returns a non-empty list of common arXiv categories.
    func testAvailableCategories() {
        let categories = viewModel.availableCategories

        XCTAssertFalse(
            categories.isEmpty,
            "availableCategories should not be empty"
        )
        XCTAssertTrue(
            categories.contains("cs.AI"),
            "availableCategories should include cs.AI"
        )
        XCTAssertTrue(
            categories.contains("cs.LG"),
            "availableCategories should include cs.LG"
        )
    }
}
