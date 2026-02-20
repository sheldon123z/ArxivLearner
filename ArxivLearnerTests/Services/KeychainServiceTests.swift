import XCTest
@testable import ArxivLearner

final class KeychainServiceTests: XCTestCase {

    // MARK: Properties

    private let sut = KeychainService.shared
    private let testKey = "com.arxivlearner.tests.keychainServiceTests"

    // MARK: Lifecycle

    override func tearDown() {
        super.tearDown()
        // Clean up any test key that may have been written during a test.
        try? sut.delete(key: testKey)
    }

    // MARK: Tests

    func testSaveAndRetrieve() throws {
        let expectedValue = "test-api-key-12345"

        try sut.save(key: testKey, value: expectedValue)
        let retrieved = try sut.retrieve(key: testKey)

        XCTAssertEqual(retrieved, expectedValue, "Retrieved value should match the saved value.")
    }

    func testDelete() throws {
        try sut.save(key: testKey, value: "value-to-delete")
        try sut.delete(key: testKey)
        let retrieved = try sut.retrieve(key: testKey)

        XCTAssertNil(retrieved, "Retrieve after delete should return nil.")
    }

    func testUpdate() throws {
        let initialValue = "initial-api-key"
        let updatedValue = "updated-api-key"

        try sut.save(key: testKey, value: initialValue)
        try sut.save(key: testKey, value: updatedValue)
        let retrieved = try sut.retrieve(key: testKey)

        XCTAssertEqual(retrieved, updatedValue, "Retrieved value should reflect the most recently saved value.")
    }
}
