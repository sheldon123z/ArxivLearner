import Foundation

// MARK: - Doc2xTaskStatus

enum Doc2xTaskStatus: Equatable {
    case processing(progress: Int)
    case completed
    case failed(String)
}

// MARK: - Doc2xError

enum Doc2xError: Error, LocalizedError {
    case invalidResponse
    case conversionFailed(String)
    case timeout
    case emptyPDFData
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Doc2x API returned an invalid or unexpected response."
        case .conversionFailed(let detail):
            return "PDF conversion failed: \(detail)"
        case .timeout:
            return "The PDF conversion timed out before completing."
        case .emptyPDFData:
            return "The provided PDF data is empty."
        case .uploadFailed(let detail):
            return "Failed to upload PDF: \(detail)"
        }
    }
}

// MARK: - Doc2xService

final class Doc2xService {

    // MARK: Constants

    static let defaultBaseURL = "https://v2.doc2x.noedgeai.com"

    // MARK: Properties

    let apiKey: String
    let baseURL: String
    private let session: URLSession

    // MARK: Init

    init(apiKey: String, baseURL: String = Doc2xService.defaultBaseURL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Public API

    /// Uploads a PDF and returns the unique task identifier (UID) assigned by Doc2x.
    ///
    /// Uses the pre-upload flow: first obtains a pre-signed URL, then uploads the
    /// PDF binary via PUT to that URL.
    func uploadPDF(pdfData: Data) async throws -> String {
        guard !pdfData.isEmpty else {
            throw Doc2xError.emptyPDFData
        }

        // Step 1: Request a pre-upload URL and UID.
        let preUploadURL = URL(string: "\(baseURL)/api/v2/parse/preupload")!
        var preUploadRequest = URLRequest(url: preUploadURL)
        preUploadRequest.httpMethod = "POST"
        preUploadRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        preUploadRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (preData, preResponse) = try await session.data(for: preUploadRequest)
        try validateHTTPResponse(preResponse)

        let preResult = try JSONDecoder().decode(Doc2xPreUploadResponse.self, from: preData)
        guard preResult.code == "success" else {
            throw Doc2xError.uploadFailed(preResult.msg ?? "Pre-upload request failed.")
        }

        let uid = preResult.data.uid
        let presignedURLString = preResult.data.url

        // Step 2: Upload the PDF binary to the pre-signed URL via PUT.
        guard let presignedURL = URL(string: presignedURLString) else {
            throw Doc2xError.invalidResponse
        }

        var uploadRequest = URLRequest(url: presignedURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = pdfData

        let (_, uploadResponse) = try await session.data(for: uploadRequest)
        try validateHTTPResponse(uploadResponse)

        return uid
    }

    /// Checks the current parsing status for the given task UID.
    func checkStatus(taskId: String) async throws -> Doc2xTaskStatus {
        let statusURL = URL(string: "\(baseURL)/api/v2/parse/status?uid=\(taskId)")!
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let statusResult = try JSONDecoder().decode(Doc2xStatusResponse.self, from: data)
        guard statusResult.code == "success" else {
            throw Doc2xError.conversionFailed(statusResult.msg ?? "Status check failed.")
        }

        guard let statusData = statusResult.data else {
            throw Doc2xError.invalidResponse
        }

        switch statusData.status {
        case "success":
            return .completed
        case "failed":
            return .failed(statusData.detail ?? "Unknown parsing error.")
        default:
            return .processing(progress: statusData.progress)
        }
    }

    /// Fetches the parsed Markdown result for a completed task.
    ///
    /// This initiates a conversion to Markdown format, polls until the conversion
    /// is ready, then downloads and returns the Markdown content.
    func fetchResult(taskId: String) async throws -> String {
        // First, check parse status to get inline Markdown from pages.
        let statusURL = URL(string: "\(baseURL)/api/v2/parse/status?uid=\(taskId)")!
        var statusRequest = URLRequest(url: statusURL)
        statusRequest.httpMethod = "GET"
        statusRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (statusData, statusResponse) = try await session.data(for: statusRequest)
        try validateHTTPResponse(statusResponse)

        let statusResult = try JSONDecoder().decode(Doc2xStatusResponse.self, from: statusData)
        guard statusResult.code == "success",
              let data = statusResult.data,
              data.status == "success",
              let result = data.result else {
            throw Doc2xError.conversionFailed("Parsing is not yet complete or failed.")
        }

        // Combine Markdown from all pages in order.
        let markdown = result.pages
            .sorted { $0.pageIdx < $1.pageIdx }
            .map { $0.md }
            .joined(separator: "\n\n")

        return markdown
    }

    /// Full conversion pipeline: upload, poll for parsing completion, and return
    /// the Markdown content.
    ///
    /// - Parameters:
    ///   - pdfData: Raw PDF binary data.
    ///   - pollInterval: Seconds between status polls. Defaults to 3 seconds.
    ///   - timeout: Maximum seconds to wait for the conversion. Defaults to 300.
    /// - Returns: The converted Markdown string.
    func convert(
        pdfData: Data,
        pollInterval: TimeInterval = 3.0,
        timeout: TimeInterval = 300.0
    ) async throws -> String {
        let taskId = try await uploadPDF(pdfData: pdfData)

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let status = try await checkStatus(taskId: taskId)

            switch status {
            case .completed:
                return try await fetchResult(taskId: taskId)

            case .failed(let message):
                throw Doc2xError.conversionFailed(message)

            case .processing:
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }

        throw Doc2xError.timeout
    }

    /// Builds a multipart/form-data upload request for the `/api/v2/parse/pdf`
    /// direct-upload endpoint. This is an alternative to the pre-upload flow and
    /// is suitable for PDFs under 300 MB.
    func buildUploadRequest(pdfData: Data) throws -> URLRequest {
        guard !pdfData.isEmpty else {
            throw Doc2xError.emptyPDFData
        }

        let boundary = UUID().uuidString
        let url = URL(string: "\(baseURL)/api/v2/parse/pdf")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
    }

    // MARK: Private Helpers

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Doc2xError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw Doc2xError.conversionFailed("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Response Models

private struct Doc2xPreUploadResponse: Decodable {
    let code: String
    let msg: String?
    let data: PreUploadData

    struct PreUploadData: Decodable {
        let uid: String
        let url: String
    }
}

private struct Doc2xStatusResponse: Decodable {
    let code: String
    let msg: String?
    let data: StatusData?

    struct StatusData: Decodable {
        let progress: Int
        let status: String
        let detail: String?
        let result: ParseResult?
    }

    struct ParseResult: Decodable {
        let version: String?
        let pages: [PageContent]
    }

    struct PageContent: Decodable {
        let url: String?
        let pageIdx: Int
        let pageWidth: Int?
        let pageHeight: Int?
        let md: String

        enum CodingKeys: String, CodingKey {
            case url
            case pageIdx = "page_idx"
            case pageWidth = "page_width"
            case pageHeight = "page_height"
            case md
        }
    }
}
