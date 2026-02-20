import Foundation

// MARK: - LLMError

enum LLMError: Error, LocalizedError {
    /// The server returned a non-2xx HTTP status code.
    case badResponse(statusCode: Int)
    /// The base URL in the provider config could not be parsed into a valid URL.
    case invalidURL
    /// The response body could not be decoded into the expected structure.
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badResponse(let statusCode):
            return "LLM service returned an unexpected status code: \(statusCode)"
        case .invalidURL:
            return "The LLM provider base URL is invalid."
        case .invalidResponse:
            return "The LLM service response could not be decoded."
        }
    }
}

// MARK: - Request / Response Codable types

// These types mirror the OpenAI Chat Completions schema:
// POST /v1/chat/completions
// Reference: https://platform.openai.com/docs/api-reference/chat

private struct ChatRequest: Encodable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
}

// Non-streaming response schema:
// { "choices": [{ "message": { "role": "assistant", "content": "..." } }] }
private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

// Streaming chunk schema (object type: "chat.completion.chunk"):
// { "choices": [{ "delta": { "content": "..." }, "finish_reason": "stop" | null }] }
private struct ChatStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
        let finish_reason: String?
    }
    let choices: [Choice]
}

// MARK: - OpenAICompatibleService

final class OpenAICompatibleService: LLMServiceProtocol {

    // MARK: Properties

    private let config: LLMProviderConfig
    private let session: URLSession

    // MARK: Init

    init(config: LLMProviderConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: Public API

    func complete(messages: [LLMMessage], stream: Bool) async throws -> String {
        if stream {
            // Collect all streaming chunks into a single string.
            var result = ""
            for try await chunk in completeStream(messages: messages) {
                result += chunk
            }
            return result
        } else {
            let request = try buildRequest(messages: messages, stream: false)
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response)

            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw LLMError.invalidResponse
            }
            return content
        }
    }

    func completeStream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(messages: messages, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try self.validateHTTPResponse(response)

                    // Each SSE line is prefixed with "data: ".
                    // The stream ends with the sentinel line "data: [DONE]".
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6)) // drop "data: "
                        guard jsonString != "[DONE]" else { break }

                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(ChatStreamChunk.self, from: jsonData)
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
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

    /// Builds the URLRequest for the Chat Completions endpoint.
    func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        let endpointString = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
            + "/chat/completions"
        guard let url = URL(string: endpointString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(model: config.modelId, messages: messages, stream: stream)
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
