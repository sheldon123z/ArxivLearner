import Foundation

// MARK: - LLMError

enum LLMError: Error, LocalizedError, Equatable {
    /// The server returned a non-2xx HTTP status code.
    case badResponse(statusCode: Int)
    /// The base URL in the provider config could not be parsed into a valid URL.
    case invalidURL
    /// The response body could not be decoded into the expected structure.
    case invalidResponse
    /// No API key was found for the given keychain reference.
    case missingAPIKey(ref: String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let statusCode):
            return "LLM service returned an unexpected status code: \(statusCode)"
        case .invalidURL:
            return "The LLM provider base URL is invalid."
        case .invalidResponse:
            return "The LLM service response could not be decoded."
        case .missingAPIKey(let ref):
            return "No API key found in Keychain for reference '\(ref)'."
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

/// Implements `LLMServiceProtocol` for any OpenAI-compatible Chat Completions endpoint.
///
/// This covers OpenAI, DeepSeek, OpenRouter, ZhiPu, DashScope, Minimax, and any
/// provider that adheres to the `/v1/chat/completions` request/response shape.
///
/// Custom HTTP headers (e.g. `HTTP-Referer` required by OpenRouter) can be injected
/// via the `customHeaders` parameter.
final class OpenAICompatibleService: LLMServiceProtocol {

    // MARK: Properties

    private let baseURL: String
    private let apiKey: String
    private let modelId: String
    private let customHeaders: [String: String]
    private let session: URLSession

    // MARK: Init

    /// Designated initialiser — provide all fields directly.
    init(
        baseURL: String,
        apiKey: String,
        modelId: String,
        customHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelId = modelId
        self.customHeaders = customHeaders
        self.session = session
    }

    /// Convenience initialiser from a legacy `LLMProviderConfig`.
    /// Retained for backward compatibility with existing call-sites.
    convenience init(config: LLMProviderConfig, session: URLSession = .shared) {
        self.init(
            baseURL: config.baseURL,
            apiKey: config.apiKey,
            modelId: config.modelId,
            session: session
        )
    }

    // MARK: LLMServiceProtocol

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
        let endpointString = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
            + "/chat/completions"
        guard let url = URL(string: endpointString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Apply any provider-specific custom headers (e.g. OpenRouter's HTTP-Referer).
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body = ChatRequest(model: modelId, messages: messages, stream: stream)
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
