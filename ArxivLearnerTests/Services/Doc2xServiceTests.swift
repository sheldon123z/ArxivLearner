import XCTest
@testable import ArxivLearner

final class Doc2xServiceTests: XCTestCase {

    // MARK: Tests – Initialization

    func testServiceInitialization() {
        let service = Doc2xService(apiKey: "sk-test-key-123")

        XCTAssertEqual(service.apiKey, "sk-test-key-123")
        XCTAssertEqual(service.baseURL, "https://v2.doc2x.noedgeai.com")
    }

    func testServiceInitializationWithCustomBaseURL() {
        let customURL = "https://custom.doc2x.example.com"
        let service = Doc2xService(apiKey: "sk-custom", baseURL: customURL)

        XCTAssertEqual(service.apiKey, "sk-custom")
        XCTAssertEqual(service.baseURL, customURL)
    }

    // MARK: Tests – Build Upload Request

    func testBuildUploadRequest() throws {
        let service = Doc2xService(apiKey: "sk-upload-test")
        let pdfData = Data("fake-pdf-content".utf8)

        let request = try service.buildUploadRequest(pdfData: pdfData)

        XCTAssertEqual(request.httpMethod, "POST", "Upload request must use POST method.")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer sk-upload-test",
            "Authorization header must use Bearer token format with the provided API key."
        )
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://v2.doc2x.noedgeai.com/api/v2/parse/pdf",
            "Request URL must point to the Doc2x PDF upload endpoint."
        )

        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        XCTAssertTrue(
            contentType.starts(with: "multipart/form-data; boundary="),
            "Content-Type must be multipart/form-data with a boundary."
        )

        XCTAssertNotNil(request.httpBody, "Request body must contain the PDF data.")
        XCTAssertGreaterThan(
            request.httpBody?.count ?? 0,
            pdfData.count,
            "Request body should be larger than raw PDF data due to multipart encoding."
        )
    }

    func testBuildUploadRequestWithEmptyDataThrows() {
        let service = Doc2xService(apiKey: "sk-empty-test")
        let emptyData = Data()

        XCTAssertThrowsError(try service.buildUploadRequest(pdfData: emptyData)) { error in
            guard let doc2xError = error as? Doc2xError else {
                XCTFail("Expected Doc2xError but got \(type(of: error)).")
                return
            }
            if case .emptyPDFData = doc2xError {
                // Expected
            } else {
                XCTFail("Expected Doc2xError.emptyPDFData but got \(doc2xError).")
            }
        }
    }
}
