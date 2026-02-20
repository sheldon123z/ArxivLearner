import XCTest
@testable import ArxivLearner

final class PDFCacheManagerTests: XCTestCase {

    // MARK: Properties

    /// An isolated cache manager that writes to a "TestPDFs" subdirectory so
    /// it never touches production data.
    private var sut: PDFCacheManager!

    // MARK: Lifecycle

    override func setUp() {
        super.setUp()
        sut = PDFCacheManager(subdirectory: "TestPDFs")
    }

    override func tearDown() {
        sut.clearCache()
        sut = nil
        super.tearDown()
    }

    // MARK: Tests

    /// The cache directory path must include the "TestPDFs" subdirectory name.
    func testCacheDirectory() {
        XCTAssertTrue(
            sut.cacheDirectory.path.contains("TestPDFs"),
            "Cache directory should be located inside a 'TestPDFs' subdirectory."
        )
    }

    /// `localPath(for:)` must produce a filename of the form "<arxivId>.pdf".
    func testLocalPathForPaper() {
        let arxivId = "2401.12345"
        let url = sut.localPath(for: arxivId)

        XCTAssertEqual(
            url.lastPathComponent,
            "\(arxivId).pdf",
            "Filename should be '\(arxivId).pdf'."
        )
        XCTAssertTrue(
            url.path.hasSuffix(".pdf"),
            "Local path must end with .pdf extension."
        )
    }

    /// `isDownloaded(arxivId:)` must return false when no file exists for the given ID.
    func testIsDownloaded() {
        let arxivId = "9999.00000"

        XCTAssertFalse(
            sut.isDownloaded(arxivId: arxivId),
            "isDownloaded should return false for a paper that has not been cached."
        )
    }

    /// `totalCacheSize()` must return 0 for an empty cache directory.
    func testCacheSize() {
        // Ensure the directory is empty before measuring.
        sut.clearCache()

        XCTAssertEqual(
            sut.totalCacheSize(),
            0,
            "Total cache size should be 0 for an empty cache directory."
        )
    }
}
