import XCTest
import SwiftData
@testable import ArxivLearner

final class PaperTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an in-memory ModelContainer configured with Paper and ChatMessage.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Paper.self, ChatMessage.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Tests

    func testPaperCreation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let paper = Paper(
            arxivId: "2401.00001",
            title: "Attention Is All You Need",
            authors: ["Vaswani", "Shazeer"],
            abstractText: "We propose the Transformer...",
            categories: ["cs.LG", "cs.CL"],
            pdfURL: "https://arxiv.org/pdf/2401.00001"
        )

        context.insert(paper)
        try context.save()

        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == "2401.00001" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        let fetched = try XCTUnwrap(results.first)
        XCTAssertEqual(fetched.arxivId, "2401.00001")
        XCTAssertEqual(fetched.title, "Attention Is All You Need")
        XCTAssertEqual(fetched.authors, ["Vaswani", "Shazeer"])
        XCTAssertEqual(fetched.categories, ["cs.LG", "cs.CL"])
        XCTAssertEqual(fetched.pdfURL, "https://arxiv.org/pdf/2401.00001")
    }

    func testPaperDefaultValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let paper = Paper(arxivId: "2401.00002")
        context.insert(paper)
        try context.save()

        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == "2401.00002" }
        )
        let results = try context.fetch(descriptor)
        let fetched = try XCTUnwrap(results.first)

        XCTAssertEqual(fetched.title, "")
        XCTAssertEqual(fetched.authors, [])
        XCTAssertEqual(fetched.abstractText, "")
        XCTAssertEqual(fetched.categories, [])
        XCTAssertEqual(fetched.pdfURL, "")
        XCTAssertNil(fetched.pdfLocalPath)
        XCTAssertFalse(fetched.isDownloaded)
        XCTAssertFalse(fetched.isFavorite)
        XCTAssertEqual(fetched.tags, [])
        XCTAssertNil(fetched.llmInsight)
        XCTAssertNil(fetched.markdownContent)
        XCTAssertEqual(fetched.convertStatus, .none)
        XCTAssertNil(fetched.markdownConvertedAt)
    }

    func testFavoriteToggle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let paper = Paper(arxivId: "2401.00003")
        XCTAssertFalse(paper.isFavorite, "New paper should not be favorited by default")

        context.insert(paper)
        try context.save()

        paper.isFavorite = true
        try context.save()

        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == "2401.00003" }
        )
        let results = try context.fetch(descriptor)
        let fetched = try XCTUnwrap(results.first)

        XCTAssertTrue(fetched.isFavorite, "Paper should be favorited after toggle")

        fetched.isFavorite = false
        try context.save()

        let results2 = try context.fetch(descriptor)
        let fetched2 = try XCTUnwrap(results2.first)
        XCTAssertFalse(fetched2.isFavorite, "Paper should not be favorited after second toggle")
    }

    func testConvertStatusRoundTrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let paper = Paper(arxivId: "2401.00004", markdownConvertStatus: .converting)
        context.insert(paper)
        try context.save()

        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == "2401.00004" }
        )
        let fetched = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(fetched.convertStatus, .converting)

        fetched.convertStatus = .completed
        try context.save()

        let fetched2 = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(fetched2.convertStatus, .completed)
        XCTAssertEqual(fetched2.markdownConvertStatus, "completed")
    }
}
