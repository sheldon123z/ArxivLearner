import Foundation

// MARK: - LLMMessage

struct LLMMessage: Codable {
    let role: String
    let content: String
}

// MARK: - LLMServiceProtocol

protocol LLMServiceProtocol {
    /// Sends a completion request and returns the full response as a single string.
    /// - Parameters:
    ///   - messages: The conversation history to send.
    ///   - stream: Whether to use streaming internally (result is still returned as a whole string).
    func complete(messages: [LLMMessage], stream: Bool) async throws -> String

    /// Sends a streaming completion request and returns an AsyncThrowingStream of partial text chunks.
    /// - Parameter messages: The conversation history to send.
    func completeStream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error>
}
