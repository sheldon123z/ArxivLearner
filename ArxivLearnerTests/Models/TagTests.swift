import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - TagTests

final class TagTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([Paper.self, Tag.self, ReadingSession.self,
                             ChatMessage.self, Annotation.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Tag Creation

    @MainActor
    func testTagCreation_basicProperties() throws {
        let tag = Tag(name: "机器学习", colorHex: "6C5CE7")
        context.insert(tag)
        try context.save()

        XCTAssertEqual(tag.name, "机器学习")
        XCTAssertEqual(tag.colorHex, "6C5CE7")
        XCTAssertNotNil(tag.createdAt)
    }

    @MainActor
    func testTagCreation_defaultsAreValid() throws {
        let tag = Tag(name: "测试标签")
        context.insert(tag)
        try context.save()

        XCTAssertEqual(tag.name, "测试标签")
        XCTAssertFalse(tag.colorHex.isEmpty, "Default color hex should not be empty")
    }

    // MARK: - Paper-Tag Relationship

    @MainActor
    func testPaperTagRelationship_addTag() throws {
        let paper = Paper(arxivId: "2401.10001", title: "Test Paper")
        let tag = Tag(name: "NLP", colorHex: "00CEC9")
        context.insert(paper)
        context.insert(tag)

        paper.tagItems.append(tag)
        try context.save()

        XCTAssertEqual(paper.tagItems.count, 1)
        XCTAssertEqual(paper.tagItems.first?.name, "NLP")
    }

    @MainActor
    func testPaperTagRelationship_removeTag() throws {
        let paper = Paper(arxivId: "2401.10002")
        let tag1 = Tag(name: "CV", colorHex: "FD79A8")
        let tag2 = Tag(name: "RL", colorHex: "FDCB6E")
        context.insert(paper)
        context.insert(tag1)
        context.insert(tag2)

        paper.tagItems = [tag1, tag2]
        try context.save()

        paper.tagItems.removeAll { $0.name == "CV" }
        try context.save()

        XCTAssertEqual(paper.tagItems.count, 1)
        XCTAssertEqual(paper.tagItems.first?.name, "RL")
    }

    @MainActor
    func testPaperTagRelationship_multiplePapersShareTag() throws {
        let paper1 = Paper(arxivId: "2401.10003")
        let paper2 = Paper(arxivId: "2401.10004")
        let sharedTag = Tag(name: "Shared", colorHex: "E17055")
        context.insert(paper1)
        context.insert(paper2)
        context.insert(sharedTag)

        paper1.tagItems.append(sharedTag)
        paper2.tagItems.append(sharedTag)
        try context.save()

        XCTAssertEqual(paper1.tagItems.count, 1)
        XCTAssertEqual(paper2.tagItems.count, 1)
    }

    // MARK: - Tag Filtering

    @MainActor
    func testTagFiltering_papersByTag() throws {
        let tagA = Tag(name: "TagA", colorHex: "6C5CE7")
        let tagB = Tag(name: "TagB", colorHex: "00CEC9")
        let paperWithA = Paper(arxivId: "2401.10005")
        let paperWithBoth = Paper(arxivId: "2401.10006")
        let paperWithNone = Paper(arxivId: "2401.10007")

        context.insert(tagA)
        context.insert(tagB)
        context.insert(paperWithA)
        context.insert(paperWithBoth)
        context.insert(paperWithNone)

        paperWithA.tagItems = [tagA]
        paperWithBoth.tagItems = [tagA, tagB]
        try context.save()

        let allPapers = [paperWithA, paperWithBoth, paperWithNone]
        let filtered = allPapers.filter { $0.tagItems.contains(where: { $0.name == "TagA" }) }

        XCTAssertEqual(filtered.count, 2, "Should find 2 papers tagged with TagA")
        XCTAssertFalse(filtered.contains(where: { $0.arxivId == "2401.10007" }))
    }
}
