import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - CloudSyncTests

final class CloudSyncTests: XCTestCase {

    // MARK: - Favorite Union Merge Tests

    func testFavoriteMerge_bothFalse_returnsFalse() {
        let result = CloudSyncManager.shared.mergedIsFavorite(local: false, remote: false)
        XCTAssertFalse(result, "Both false should yield false")
    }

    func testFavoriteMerge_localTrue_returnsTrue() {
        let result = CloudSyncManager.shared.mergedIsFavorite(local: true, remote: false)
        XCTAssertTrue(result, "Local true should yield true (union strategy)")
    }

    func testFavoriteMerge_remoteTrue_returnsTrue() {
        let result = CloudSyncManager.shared.mergedIsFavorite(local: false, remote: true)
        XCTAssertTrue(result, "Remote true should yield true (union strategy)")
    }

    func testFavoriteMerge_bothTrue_returnsTrue() {
        let result = CloudSyncManager.shared.mergedIsFavorite(local: true, remote: true)
        XCTAssertTrue(result, "Both true should yield true")
    }

    // MARK: - Apply Favorite Merge Tests

    @MainActor
    func testApplyFavoriteMerge_updatesMultiplePapers() async throws {
        let schema = Schema([Paper.self, ReadingSession.self, ChatMessage.self,
                             Tag.self, Annotation.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let paper1 = Paper(arxivId: "2401.00001", isFavorite: false)
        let paper2 = Paper(arxivId: "2401.00002", isFavorite: true)
        context.insert(paper1)
        context.insert(paper2)

        let remoteValues: [String: Bool] = [
            "2401.00001": true,   // remote true, local false -> should become true
            "2401.00002": false,  // remote false, local true -> should stay true
        ]

        CloudSyncManager.shared.applyFavoriteMerge(
            papers: [paper1, paper2],
            remoteValues: remoteValues
        )

        XCTAssertTrue(paper1.isFavorite, "Union: local false + remote true = true")
        XCTAssertTrue(paper2.isFavorite, "Union: local true + remote false = true")
    }

    // MARK: - Sync Status Test

    func testICloudAvailabilityCheck() {
        // On simulator without iCloud account this will be false; just verify no crash
        let available = CloudSyncManager.shared.isICloudAvailable
        // Just asserting the call doesn't crash; value depends on test environment
        XCTAssertNotNil(available)
    }
}
