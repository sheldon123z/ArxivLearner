import Foundation

// MARK: - LLMRouter

/// Routes LLM completion requests to the appropriate service implementation based on
/// the provider's `ProviderType`.
///
/// API keys are retrieved from `KeychainService` using `provider.apiKeyRef` at
/// call-time so they are never held in memory longer than necessary.
///
/// **Provider routing table:**
/// | ProviderType                                                        | Service                  |
/// |---------------------------------------------------------------------|--------------------------|
/// | .openai, .deepseek, .openRouter, .customOpenAI, .zhipu, .dashscope, .minimax | OpenAICompatibleService |
/// | .anthropic                                                          | AnthropicService         |
/// | .google                                                             | GeminiService            |
final class LLMRouter {

    // MARK: Singleton

    static let shared = LLMRouter()

    // MARK: Init

    private init() {}

    // MARK: Public API

    /// Sends a completion request and returns the full response as a single string.
    ///
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - provider: The configured `LLMProvider` (SwiftData model).
    ///   - model: The selected `LLMModel` (SwiftData model).
    ///   - stream: When `true` the underlying service uses SSE streaming but the
    ///             result is still accumulated and returned as a single `String`.
    func complete(
        messages: [LLMMessage],
        provider: LLMProvider,
        model: LLMModel,
        stream: Bool
    ) async throws -> String {
        let service = try resolveService(provider: provider, model: model)
        return try await service.complete(messages: messages, stream: stream)
    }

    /// Returns an `AsyncThrowingStream` of partial text chunks for the given request.
    ///
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - provider: The configured `LLMProvider` (SwiftData model).
    ///   - model: The selected `LLMModel` (SwiftData model).
    func completeStream(
        messages: [LLMMessage],
        provider: LLMProvider,
        model: LLMModel
    ) -> AsyncThrowingStream<String, Error> {
        // Resolve service synchronously; if resolution fails wrap the error in the stream.
        guard let service = try? resolveService(provider: provider, model: model) else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMError.missingAPIKey(ref: provider.apiKeyRef))
            }
        }
        return service.completeStream(messages: messages)
    }

    // MARK: 2.5 - Connectivity Test

    /// Sends a simple "Hi" message to verify the provider is reachable and measures
    /// round-trip latency.
    ///
    /// - Parameters:
    ///   - provider: The configured `LLMProvider` to test.
    ///   - model: The model to use for the test call.
    /// - Returns: A tuple containing success status, latency in milliseconds, and an
    ///            optional human-readable error string.
    func testConnectivity(
        provider: LLMProvider,
        model: LLMModel
    ) async -> (success: Bool, latencyMs: Int, error: String?) {
        let probe = [LLMMessage(role: "user", content: "Hi")]
        let start = Date()

        do {
            _ = try await complete(messages: probe, provider: provider, model: model, stream: false)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return (success: true, latencyMs: latency, error: nil)
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return (success: false, latencyMs: latency, error: error.localizedDescription)
        }
    }

    // MARK: Private helpers

    /// Resolves the concrete `LLMServiceProtocol` implementation for the given provider
    /// and model pair. Retrieves the API key from Keychain.
    private func resolveService(provider: LLMProvider, model: LLMModel) throws -> LLMServiceProtocol {
        let apiKey = (try? KeychainService.shared.retrieve(key: provider.apiKeyRef)) ?? ""

        switch provider.type {
        case .anthropic:
            return AnthropicService(
                baseURL: provider.baseURL,
                apiKey: apiKey,
                modelId: model.modelId
            )

        case .google:
            return GeminiService(
                baseURL: provider.baseURL,
                apiKey: apiKey,
                modelId: model.modelId
            )

        case .openai, .deepseek, .customOpenAI, .zhipu, .dashscope, .minimax:
            return OpenAICompatibleService(
                baseURL: provider.baseURL,
                apiKey: apiKey,
                modelId: model.modelId,
                customHeaders: provider.customHeaders ?? [:]
            )

        case .openRouter:
            // OpenRouter requires HTTP-Referer and X-Title headers for attribution.
            var headers = provider.customHeaders ?? [:]
            headers["HTTP-Referer"] = headers["HTTP-Referer"] ?? "https://github.com/arxivlearner"
            headers["X-Title"] = headers["X-Title"] ?? "ArxivLearner"
            return OpenAICompatibleService(
                baseURL: provider.baseURL,
                apiKey: apiKey,
                modelId: model.modelId,
                customHeaders: headers
            )
        }
    }
}
