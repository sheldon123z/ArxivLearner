import Foundation

// MARK: - Request / Response Codable types

// These types mirror the Google Gemini generateContent API schema:
// POST /v1beta/models/{model}:generateContent?key={apiKey}
// Reference: https://ai.google.dev/api/generate-content

private struct GeminiRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let parts: [Part]
    }
    let contents: [Content]
}

// Non-streaming response schema:
// { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - GeminiService

/// Implements `LLMServiceProtocol` for the Google Gemini API.
///
/// Non-streaming uses `generateContent`; streaming uses `streamGenerateContent` with
/// `alt=sse` which delivers standard SSE lines containing JSON-encoded response chunks.
final class GeminiService: LLMServiceProtocol {

    // MARK: Properties

    private let baseURL: String
    private let apiKey: String
    private let modelId: String
    private let session: URLSession

    // MARK: Init

    init(
        baseURL: String = "https://generativelanguage.googleapis.com",
        apiKey: String,
        modelId: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelId = modelId
        self.session = session
    }

    // MARK: LLMServiceProtocol

    func complete(messages: [LLMMessage], stream: Bool) async throws -> String {
        if stream {
            var result = ""
            for try await chunk in completeStream(messages: messages) {
                result += chunk
            }
            return result
        } else {
            let request = try buildRequest(messages: messages, stream: false)
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response)

            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let text = decoded.candidates.first?.content.parts.first?.text else {
                throw LLMError.invalidResponse
            }
            return text
        }
    }

    func completeStream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(messages: messages, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try self.validateHTTPResponse(response)

                    // Gemini SSE lines are prefixed with "data: ".
                    // Each line carries a full GeminiResponse JSON chunk.
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }

                        let chunk = try JSONDecoder().decode(GeminiResponse.self, from: jsonData)
                        if let text = chunk.candidates.first?.content.parts.first?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Internal helpers (internal access for unit testing)

    /// Builds the URLRequest for either generateContent or streamGenerateContent.
    func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        let base = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        let action = stream ? "streamGenerateContent" : "generateContent"
        var urlString = "\(base)/v1beta/models/\(modelId):\(action)?key=\(apiKey)"
        if stream {
            urlString += "&alt=sse"
        }

        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini accepts a flat list of user messages; we concatenate them into a single
        // turn using the conversation history as ordered parts.
        let parts = messages.map { GeminiRequest.Content.Part(text: "\($0.role): \($0.content)") }
        let body = GeminiRequest(contents: [GeminiRequest.Content(parts: parts)])
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: Private helpers

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.badResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.badResponse(statusCode: httpResponse.statusCode)
        }
    }
}
