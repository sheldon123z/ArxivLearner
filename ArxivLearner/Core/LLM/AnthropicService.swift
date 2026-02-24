import Foundation

// MARK: - Request / Response Codable types

// These types mirror the Anthropic Messages API schema:
// POST /v1/messages
// Reference: https://docs.anthropic.com/en/api/messages

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [LLMMessage]
    let stream: Bool
}

// Non-streaming response schema:
// { "content": [{ "type": "text", "text": "..." }] }
private struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    let content: [ContentBlock]
}

// Streaming delta schema used inside SSE data lines:
// { "type": "content_block_delta", "delta": { "type": "text_delta", "text": "..." } }
private struct AnthropicStreamDelta: Decodable {
    struct Delta: Decodable {
        let type: String
        let text: String?
    }
    let type: String
    let delta: Delta?
}

// MARK: - AnthropicService

/// Implements `LLMServiceProtocol` for the Anthropic Messages API.
///
/// Auth uses `x-api-key` plus the required `anthropic-version` header.
/// SSE streaming parses `event: content_block_delta` frames and stops at `event: message_stop`.
final class AnthropicService: LLMServiceProtocol {

    // MARK: Constants

    private static let anthropicVersion = "2023-06-01"
    private static let defaultMaxTokens = 4096

    // MARK: Properties

    private let baseURL: String
    private let apiKey: String
    private let modelId: String
    private let session: URLSession

    // MARK: Init

    init(baseURL: String, apiKey: String, modelId: String, session: URLSession = .shared) {
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

            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
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

                    // Anthropic SSE format uses pairs of lines:
                    //   event: <event-name>
                    //   data: <json-payload>
                    // We track the most recent event type and yield text only for
                    // content_block_delta events. The stream ends at message_stop.
                    var pendingEvent: String?

                    for try await line in bytes.lines {
                        if line.hasPrefix("event: ") {
                            pendingEvent = String(line.dropFirst(7))
                            // Stop immediately when the server signals the end.
                            if pendingEvent == "message_stop" {
                                break
                            }
                        } else if line.hasPrefix("data: ") {
                            guard pendingEvent == "content_block_delta" else { continue }
                            let jsonString = String(line.dropFirst(6))
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }

                            let delta = try JSONDecoder().decode(AnthropicStreamDelta.self, from: jsonData)
                            if let text = delta.delta?.text {
                                continuation.yield(text)
                            }
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

    /// Builds the URLRequest for the Messages endpoint.
    func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        let endpointString = baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
            + "/messages"
        guard let url = URL(string: endpointString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let body = AnthropicRequest(
            model: modelId,
            max_tokens: Self.defaultMaxTokens,
            messages: messages,
            stream: stream
        )
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
