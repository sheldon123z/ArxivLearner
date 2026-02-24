import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - SearchHistoryTests

final class SearchHistoryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SearchHistory.self, SavedSearch.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Search History Recording

    @MainActor
    func testSearchHistory_recordsQuery() throws {
        let history = SearchHistory(query: "transformer attention", filterCategory: "cs.AI")
        context.insert(history)
        try context.save()

        XCTAssertEqual(history.query, "transformer attention")
        XCTAssertEqual(history.filterCategory, "cs.AI")
        XCTAssertNotNil(history.timestamp)
    }

    @MainActor
    func testSearchHistory_multipleEntries() throws {
        let queries = ["diffusion model", "RLHF", "LLM alignment"]
        for query in queries {
            context.insert(SearchHistory(query: query))
        }
        try context.save()

        let descriptor = FetchDescriptor<SearchHistory>(sortBy: [SortDescriptor(\.timestamp)])
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 3)
    }

    @MainActor
    func testSearchHistory_recordsTimestamp() throws {
        let before = Date.now
        let history = SearchHistory(query: "test query")
        context.insert(history)
        try context.save()
        let after = Date.now

        XCTAssertGreaterThanOrEqual(history.timestamp, before)
        XCTAssertLessThanOrEqual(history.timestamp, after)
    }

    // MARK: - SavedSearch CRUD

    @MainActor
    func testSavedSearch_create() throws {
        let saved = SavedSearch(name: "我的搜索", query: "neural network", filterCategory: "cs.LG")
        context.insert(saved)
        try context.save()

        XCTAssertEqual(saved.name, "我的搜索")
        XCTAssertEqual(saved.query, "neural network")
        XCTAssertEqual(saved.filterCategory, "cs.LG")
        XCTAssertTrue(saved.isEnabled)
    }

    @MainActor
    func testSavedSearch_read() throws {
        context.insert(SavedSearch(name: "搜索1", query: "vision transformer"))
        context.insert(SavedSearch(name: "搜索2", query: "speech recognition"))
        try context.save()

        let descriptor = FetchDescriptor<SavedSearch>(sortBy: [SortDescriptor(\.createdAt)])
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 2)
    }

    @MainActor
    func testSavedSearch_update() throws {
        let saved = SavedSearch(name: "旧名称", query: "old query")
        context.insert(saved)
        try context.save()

        saved.name = "新名称"
        saved.query = "new query"
        try context.save()

        XCTAssertEqual(saved.name, "新名称")
        XCTAssertEqual(saved.query, "new query")
    }

    @MainActor
    func testSavedSearch_delete() throws {
        let saved = SavedSearch(name: "待删除", query: "delete me")
        context.insert(saved)
        try context.save()

        context.delete(saved)
        try context.save()

        let descriptor = FetchDescriptor<SavedSearch>()
        let all = try context.fetch(descriptor)
        XCTAssertEqual(all.count, 0)
    }

    @MainActor
    func testSavedSearch_disableToggle() throws {
        let saved = SavedSearch(name: "可禁用搜索", query: "test")
        context.insert(saved)
        try context.save()

        XCTAssertTrue(saved.isEnabled)
        saved.isEnabled = false
        try context.save()
        XCTAssertFalse(saved.isEnabled)
    }
}
