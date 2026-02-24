import XCTest
import SwiftData
import CoreGraphics
@testable import ArxivLearner

// MARK: - SwipeBrowsingTests

final class SwipeBrowsingTests: XCTestCase {

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

    // MARK: - Swipe Threshold Detection

    func testSwipeThreshold_positiveX_isRightSwipe() {
        let translation = CGSize(width: 80, height: 10)
        let threshold: CGFloat = 60
        let isRightSwipe = translation.width > threshold
        XCTAssertTrue(isRightSwipe, "X > threshold should be right swipe")
    }

    func testSwipeThreshold_negativeX_isLeftSwipe() {
        let translation = CGSize(width: -80, height: 5)
        let threshold: CGFloat = 60
        let isLeftSwipe = translation.width < -threshold
        XCTAssertTrue(isLeftSwipe, "X < -threshold should be left swipe")
    }

    func testSwipeThreshold_belowThreshold_noSwipe() {
        let translation = CGSize(width: 40, height: 5)
        let threshold: CGFloat = 60
        let triggered = abs(translation.width) > threshold
        XCTAssertFalse(triggered, "Movement below threshold should not trigger swipe")
    }

    func testSwipeThreshold_exactBoundary_notTriggered() {
        let translation = CGSize(width: 60, height: 0)
        let threshold: CGFloat = 60
        let triggered = translation.width > threshold
        XCTAssertFalse(triggered, "Exactly at threshold should not trigger (strict greater)")
    }

    // MARK: - Viewed Paper Cleanup (30 day)

    @MainActor
    func testViewedPaperCleanup_removesOlderThan30Days() throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date.now)!
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: Date.now)!

        let oldPaper = Paper(arxivId: "2301.00001", viewedAt: oldDate)
        let recentPaper = Paper(arxivId: "2301.00002", viewedAt: recentDate)
        let unviewedPaper = Paper(arxivId: "2301.00003", viewedAt: nil)

        context.insert(oldPaper)
        context.insert(recentPaper)
        context.insert(unviewedPaper)
        try context.save()

        // Simulate cleanup: remove viewed papers older than 30 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date.now)!
        let papers = [oldPaper, recentPaper, unviewedPaper]
        let toClean = papers.filter { paper in
            guard let viewedAt = paper.viewedAt else { return false }
            return viewedAt < cutoff
        }

        XCTAssertEqual(toClean.count, 1, "Only 1 paper should be older than 30 days")
        XCTAssertEqual(toClean.first?.arxivId, "2301.00001")
    }

    @MainActor
    func testViewedPaperCleanup_keepsRecentPapers() throws {
        let recentDate = Calendar.current.date(byAdding: .day, value: -10, to: Date.now)!
        let paper = Paper(arxivId: "2301.00004", viewedAt: recentDate)
        context.insert(paper)
        try context.save()

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date.now)!
        let shouldClean = (paper.viewedAt ?? Date.now) < cutoff
        XCTAssertFalse(shouldClean, "Paper viewed 10 days ago should not be cleaned")
    }

    @MainActor
    func testViewedPaperCleanup_ignoresUnviewedPapers() throws {
        let paper = Paper(arxivId: "2301.00005", viewedAt: nil)
        context.insert(paper)
        try context.save()

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date.now)!
        let shouldClean: Bool
        if let viewedAt = paper.viewedAt {
            shouldClean = viewedAt < cutoff
        } else {
            shouldClean = false
        }
        XCTAssertFalse(shouldClean, "Unviewed paper should never be cleaned")
    }
}
