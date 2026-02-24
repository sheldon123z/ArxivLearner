import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - LLMRouterTests
//
// Strategy: LLMRouter.resolveService(_:_:) is private, so we test the routing logic
// indirectly by exercising the concrete service types (AnthropicService,
// GeminiService, OpenAICompatibleService) through their internal buildRequest method.
//
// This lets us verify that:
//   - AnthropicService produces the correct endpoint URL and x-api-key header.
//   - GeminiService produces the correct endpoint URL with the API key as a query param.
//   - OpenAICompatibleService produces the correct endpoint URL and Bearer auth header.
//   - OpenRouter-specific custom headers (HTTP-Referer, X-Title) are forwarded.
//
// In addition, testConnectivity is tested end-to-end through LLMRouter.shared using an
// in-memory SwiftData container so that the SwiftData @Model graph is satisfied.
// The connectivity test is expected to fail (no real network / no valid key) but the
// return type — (success: Bool, latencyMs: Int, error: String?) — is verified.

final class LLMRouterTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a throw-away in-memory ModelContainer containing the given provider and model.
    /// The container is discarded after each test; no data is persisted to disk.
    @MainActor
    private func makeInMemoryContainer(
        provider: LLMProvider,
        model: LLMModel
    ) throws -> ModelContainer {
        let schema = Schema([LLMProvider.self, LLMModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        container.mainContext.insert(provider)
        container.mainContext.insert(model)
        return container
    }

    // MARK: - AnthropicService buildRequest Tests

    func testAnthropicServiceBuildRequestURLEndsWithMessages() throws {
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1",
            apiKey: "test-anthropic-key",
            modelId: "claude-sonnet-4-20250514"
        )
        let messages = [LLMMessage(role: "user", content: "Hello")]

        let request = try service.buildRequest(messages: messages, stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.anthropic.com/v1/messages",
            "AnthropicService endpoint must be baseURL + /messages"
        )
    }

    func testAnthropicServiceBuildRequestStripsTrailingSlashFromBaseURL() throws {
        // A trailing slash on the base URL must not produce a double slash in the path.
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1/",
            apiKey: "test-key",
            modelId: "claude-haiku-4-5-20251001"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.anthropic.com/v1/messages",
            "Trailing slash in base URL must be stripped before /messages is appended"
        )
    }

    func testAnthropicServiceBuildRequestSetsXApiKeyHeader() throws {
        let expectedKey = "sk-ant-api03-testkey"
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1",
            apiKey: expectedKey,
            modelId: "claude-sonnet-4-20250514"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "x-api-key"),
            expectedKey,
            "AnthropicService must set x-api-key header with the provided API key"
        )
    }

    func testAnthropicServiceBuildRequestSetsContentTypeJSON() throws {
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1",
            apiKey: "key",
            modelId: "claude-sonnet-4-20250514"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json",
            "AnthropicService must set Content-Type: application/json"
        )
    }

    func testAnthropicServiceBuildRequestMethodIsPOST() throws {
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1",
            apiKey: "key",
            modelId: "claude-sonnet-4-20250514"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(request.httpMethod, "POST", "HTTP method must be POST")
    }

    func testAnthropicServiceBuildRequestHasNonNilBody() throws {
        let service = AnthropicService(
            baseURL: "https://api.anthropic.com/v1",
            apiKey: "key",
            modelId: "claude-sonnet-4-20250514"
        )
        let messages = [LLMMessage(role: "user", content: "test")]
        let request = try service.buildRequest(messages: messages, stream: false)

        XCTAssertNotNil(request.httpBody, "Request body must not be nil")
    }

    func testAnthropicServiceBuildRequestThrowsOnInvalidURL() {
        let service = AnthropicService(
            baseURL: "ht tp://bad url with spaces",
            apiKey: "key",
            modelId: "claude-sonnet-4-20250514"
        )

        XCTAssertThrowsError(
            try service.buildRequest(messages: [], stream: false)
        ) { error in
            XCTAssertEqual(
                error as? LLMError, .invalidURL,
                "buildRequest must throw LLMError.invalidURL for a malformed base URL"
            )
        }
    }

    // MARK: - GeminiService buildRequest Tests

    func testGeminiServiceBuildRequestURLContainsModelId() throws {
        let modelId = "gemini-2.5-pro-preview"
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "AIza-test-key",
            modelId: modelId
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertTrue(
            request.url?.absoluteString.contains(modelId) ?? false,
            "GeminiService URL must contain the model ID"
        )
    }

    func testGeminiServiceBuildRequestURLContainsApiKeyQueryParam() throws {
        let apiKey = "AIza-test-key-12345"
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: apiKey,
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        // The API key is passed as ?key=<apiKey> in the query string, not as a header.
        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(
            urlString.contains("key=\(apiKey)"),
            "GeminiService URL must include 'key=<apiKey>' as a query parameter"
        )
    }

    func testGeminiServiceNonStreamingURLUsesGenerateContent() throws {
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "key",
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertTrue(
            request.url?.absoluteString.contains("generateContent") ?? false,
            "Non-streaming GeminiService request must use the generateContent action"
        )
        XCTAssertFalse(
            request.url?.absoluteString.contains("streamGenerateContent") ?? true,
            "Non-streaming GeminiService request must not use streamGenerateContent"
        )
    }

    func testGeminiServiceStreamingURLUsesStreamGenerateContent() throws {
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "key",
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: true)

        XCTAssertTrue(
            request.url?.absoluteString.contains("streamGenerateContent") ?? false,
            "Streaming GeminiService request must use the streamGenerateContent action"
        )
    }

    func testGeminiServiceStreamingURLContainsAltSseParam() throws {
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "key",
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: true)

        XCTAssertTrue(
            request.url?.absoluteString.contains("alt=sse") ?? false,
            "Streaming GeminiService request URL must include alt=sse"
        )
    }

    func testGeminiServiceBuildRequestMethodIsPOST() throws {
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "key",
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(request.httpMethod, "POST", "HTTP method must be POST")
    }

    func testGeminiServiceBuildRequestURLPathContainsV1beta() throws {
        let service = GeminiService(
            baseURL: "https://generativelanguage.googleapis.com",
            apiKey: "key",
            modelId: "gemini-2.5-flash"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertTrue(
            request.url?.absoluteString.contains("/v1beta/") ?? false,
            "GeminiService URL must include the /v1beta/ path segment"
        )
    }

    func testGeminiServiceBuildRequestThrowsOnInvalidURL() {
        let service = GeminiService(
            baseURL: "ht tp://bad url with spaces",
            apiKey: "key",
            modelId: "gemini-model"
        )

        XCTAssertThrowsError(
            try service.buildRequest(messages: [], stream: false)
        ) { error in
            XCTAssertEqual(
                error as? LLMError, .invalidURL,
                "buildRequest must throw LLMError.invalidURL for a malformed base URL"
            )
        }
    }

    // MARK: - OpenAICompatibleService buildRequest Tests (covers .openai, .deepseek,
    //         .customOpenAI, .zhipu, .dashscope, .minimax)

    func testOpenAICompatibleServiceBuildRequestURLEndsWithChatCompletions() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test-12345",
            modelId: "gpt-4o"
        )
        let messages = [LLMMessage(role: "user", content: "Hello")]
        let request = try service.buildRequest(messages: messages, stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions",
            "OpenAICompatibleService endpoint must be baseURL + /chat/completions"
        )
    }

    func testOpenAICompatibleServiceBuildRequestStripsTrailingSlash() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1/",
            apiKey: "key",
            modelId: "gpt-4o-mini"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions",
            "Trailing slash in base URL must be stripped before /chat/completions is appended"
        )
    }

    func testOpenAICompatibleServiceBuildRequestSetsBearerAuthHeader() throws {
        let apiKey = "sk-test-bearer-auth"
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: apiKey,
            modelId: "gpt-4o"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(apiKey)",
            "OpenAICompatibleService must use 'Bearer <apiKey>' Authorization header"
        )
    }

    func testOpenAICompatibleServiceBuildRequestMethodIsPOST() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "key",
            modelId: "gpt-4o"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(request.httpMethod, "POST", "HTTP method must be POST")
    }

    func testOpenAICompatibleServiceBuildRequestSetsContentTypeJSON() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "key",
            modelId: "gpt-4o"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json",
            "OpenAICompatibleService must set Content-Type: application/json"
        )
    }

    func testOpenAICompatibleServiceBuildRequestHasNonNilBody() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "key",
            modelId: "gpt-4o"
        )
        let messages = [LLMMessage(role: "user", content: "Hi")]
        let request = try service.buildRequest(messages: messages, stream: false)

        XCTAssertNotNil(request.httpBody, "Request body must not be nil")
    }

    func testOpenAICompatibleServiceBuildRequestThrowsOnInvalidURL() {
        let service = OpenAICompatibleService(
            baseURL: "ht tp://bad url with spaces",
            apiKey: "key",
            modelId: "gpt-4o"
        )

        XCTAssertThrowsError(
            try service.buildRequest(messages: [], stream: false)
        ) { error in
            XCTAssertEqual(
                error as? LLMError, .invalidURL,
                "buildRequest must throw LLMError.invalidURL for a malformed base URL"
            )
        }
    }

    // MARK: DeepSeek endpoint shape (same service class as OpenAI)

    func testDeepSeekProviderEndpointShape() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.deepseek.com/v1",
            apiKey: "ds-test-key",
            modelId: "deepseek-chat"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.deepseek.com/v1/chat/completions",
            "DeepSeek provider must route to /chat/completions"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer ds-test-key",
            "DeepSeek provider must use Bearer auth"
        )
    }

    // MARK: Zhipu endpoint shape

    func testZhipuProviderEndpointShape() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            apiKey: "zhipu-test-key",
            modelId: "glm-4-plus"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            "Zhipu provider must route to /chat/completions"
        )
    }

    // MARK: DashScope endpoint shape

    func testDashScopeProviderEndpointShape() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            apiKey: "dashscope-test-key",
            modelId: "qwen-plus"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
            "DashScope provider must route to /chat/completions"
        )
    }

    // MARK: Minimax endpoint shape

    func testMinimaxProviderEndpointShape() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.minimax.chat/v1",
            apiKey: "minimax-test-key",
            modelId: "MiniMax-Text-01"
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.minimax.chat/v1/chat/completions",
            "Minimax provider must route to /chat/completions"
        )
    }

    // MARK: - OpenRouter-Specific Header Tests

    func testOpenRouterServiceForwardsHTTPRefererHeader() throws {
        let referer = "https://github.com/arxivlearner"
        let customHeaders: [String: String] = [
            "HTTP-Referer": referer,
            "X-Title": "ArxivLearner"
        ]
        let service = OpenAICompatibleService(
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "or-test-key",
            modelId: "anthropic/claude-sonnet-4",
            customHeaders: customHeaders
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "HTTP-Referer"),
            referer,
            "OpenRouter service must forward the HTTP-Referer custom header"
        )
    }

    func testOpenRouterServiceForwardsXTitleHeader() throws {
        let customHeaders: [String: String] = [
            "HTTP-Referer": "https://github.com/arxivlearner",
            "X-Title": "ArxivLearner"
        ]
        let service = OpenAICompatibleService(
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "or-test-key",
            modelId: "openai/gpt-4o",
            customHeaders: customHeaders
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Title"),
            "ArxivLearner",
            "OpenRouter service must forward the X-Title custom header"
        )
    }

    func testOpenRouterServiceDefaultHeadersAppliedWhenNotProvided() throws {
        // When no custom headers are supplied, the router adds the attribution defaults.
        // We simulate exactly what LLMRouter.resolveService does for .openRouter.
        var headers: [String: String] = [:]
        headers["HTTP-Referer"] = headers["HTTP-Referer"] ?? "https://github.com/arxivlearner"
        headers["X-Title"] = headers["X-Title"] ?? "ArxivLearner"

        let service = OpenAICompatibleService(
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "or-test-key",
            modelId: "anthropic/claude-sonnet-4",
            customHeaders: headers
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "HTTP-Referer"),
            "https://github.com/arxivlearner",
            "When HTTP-Referer is absent, the default 'https://github.com/arxivlearner' must be applied"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Title"),
            "ArxivLearner",
            "When X-Title is absent, the default 'ArxivLearner' must be applied"
        )
    }

    func testOpenRouterServiceCustomHeadersAreNotOverridden() throws {
        // If the caller already provides HTTP-Referer / X-Title, the router must
        // NOT overwrite them (the ?? operator in resolveService preserves existing values).
        let customReferer = "https://my-custom-app.example.com"
        let customTitle = "MyCustomApp"
        var headers: [String: String] = [
            "HTTP-Referer": customReferer,
            "X-Title": customTitle
        ]
        // Simulate router logic: only set defaults when keys are absent.
        headers["HTTP-Referer"] = headers["HTTP-Referer"] ?? "https://github.com/arxivlearner"
        headers["X-Title"] = headers["X-Title"] ?? "ArxivLearner"

        let service = OpenAICompatibleService(
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "or-test-key",
            modelId: "openai/gpt-4o",
            customHeaders: headers
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "HTTP-Referer"),
            customReferer,
            "Existing HTTP-Referer value must not be overwritten by router defaults"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Title"),
            customTitle,
            "Existing X-Title value must not be overwritten by router defaults"
        )
    }

    func testOpenRouterServiceEndpointURL() throws {
        let customHeaders: [String: String] = [
            "HTTP-Referer": "https://github.com/arxivlearner",
            "X-Title": "ArxivLearner"
        ]
        let service = OpenAICompatibleService(
            baseURL: "https://openrouter.ai/api/v1",
            apiKey: "or-test-key",
            modelId: "google/gemini-2.5-pro-preview",
            customHeaders: customHeaders
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://openrouter.ai/api/v1/chat/completions",
            "OpenRouter endpoint must be baseURL + /chat/completions"
        )
    }

    // MARK: - Custom Headers Forwarding Tests

    func testCustomHeadersAreForwardedToRequest() throws {
        let customHeaders: [String: String] = [
            "X-Custom-Header": "custom-value",
            "X-Org-Id": "org-12345"
        ]
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "key",
            modelId: "gpt-4o",
            customHeaders: customHeaders
        )
        let request = try service.buildRequest(messages: [], stream: false)

        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Custom-Header"),
            "custom-value",
            "Custom headers must be forwarded to the URLRequest"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Org-Id"),
            "org-12345",
            "All custom headers must be forwarded to the URLRequest"
        )
    }

    func testNoCustomHeadersDoesNotAffectStandardHeaders() throws {
        let service = OpenAICompatibleService(
            baseURL: "https://api.openai.com/v1",
            apiKey: "bearer-key",
            modelId: "gpt-4o"
            // No customHeaders — defaults to [:]
        )
        let request = try service.buildRequest(messages: [], stream: false)

        // Standard headers must still be present when customHeaders is empty.
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer bearer-key",
            "Standard Authorization header must be present even with no custom headers"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json",
            "Standard Content-Type header must be present even with no custom headers"
        )
    }

    // MARK: - LLMRouter.testConnectivity Return Type Tests

    @MainActor
    func testConnectivityReturnsTupleWithExpectedFields() async throws {
        // Build an in-memory SwiftData container and insert a provider + model.
        // We use an empty apiKeyRef so KeychainService returns nil and the service
        // immediately fails with a network/auth error — but what we verify here is
        // that testConnectivity always returns the expected tuple shape.
        let schema = Schema([LLMProvider.self, LLMModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        let provider = LLMProvider(
            name: "Test Provider",
            providerType: .openai,
            baseURL: "https://api.openai.com/v1",
            apiKeyRef: ""  // Empty ref — Keychain returns nil, apiKey becomes ""
        )
        let model = LLMModel(
            modelId: "gpt-4o-mini",
            displayName: "GPT-4o Mini"
        )

        container.mainContext.insert(provider)
        container.mainContext.insert(model)

        // testConnectivity must never throw; it always returns a tuple.
        let result = await LLMRouter.shared.testConnectivity(
            provider: provider,
            model: model
        )

        // The call will fail (no real network), but the tuple fields must be present.
        XCTAssertFalse(
            result.success,
            "Connectivity test with an invalid/empty API key must return success = false"
        )
        XCTAssertGreaterThanOrEqual(
            result.latencyMs, 0,
            "Latency must be a non-negative integer"
        )
        XCTAssertNotNil(
            result.error,
            "An error string must be present when connectivity fails"
        )
    }

    @MainActor
    func testConnectivityReturnsLatencyAsNonNegativeInteger() async throws {
        let schema = Schema([LLMProvider.self, LLMModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        let provider = LLMProvider(
            name: "Anthropic Test",
            providerType: .anthropic,
            baseURL: "https://api.anthropic.com/v1",
            apiKeyRef: ""
        )
        let model = LLMModel(
            modelId: "claude-haiku-4-5-20251001",
            displayName: "Claude Haiku 4.5"
        )

        container.mainContext.insert(provider)
        container.mainContext.insert(model)

        let result = await LLMRouter.shared.testConnectivity(
            provider: provider,
            model: model
        )

        XCTAssertGreaterThanOrEqual(
            result.latencyMs, 0,
            "Latency in milliseconds must always be >= 0 regardless of outcome"
        )
    }

    @MainActor
    func testConnectivityErrorStringIsNonEmptyOnFailure() async throws {
        let schema = Schema([LLMProvider.self, LLMModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        let provider = LLMProvider(
            name: "Gemini Test",
            providerType: .google,
            baseURL: "https://generativelanguage.googleapis.com",
            apiKeyRef: ""
        )
        let model = LLMModel(
            modelId: "gemini-2.5-flash",
            displayName: "Gemini 2.5 Flash"
        )

        container.mainContext.insert(provider)
        container.mainContext.insert(model)

        let result = await LLMRouter.shared.testConnectivity(
            provider: provider,
            model: model
        )

        if !result.success {
            XCTAssertNotNil(
                result.error,
                "A failed connectivity test must include a non-nil error description"
            )
            if let errorString = result.error {
                XCTAssertFalse(
                    errorString.isEmpty,
                    "Error description string must not be empty"
                )
            }
        }
    }

    // MARK: - ProviderType Enum Coverage Tests
    //
    // These tests verify the ProviderType raw values and display names match
    // the documented routing table, giving us confidence that new provider types
    // added in future are also covered.

    func testProviderTypeRawValues() {
        XCTAssertEqual(ProviderType.openai.rawValue, "openai")
        XCTAssertEqual(ProviderType.anthropic.rawValue, "anthropic")
        XCTAssertEqual(ProviderType.google.rawValue, "google")
        XCTAssertEqual(ProviderType.deepseek.rawValue, "deepseek")
        XCTAssertEqual(ProviderType.openRouter.rawValue, "openRouter")
        XCTAssertEqual(ProviderType.customOpenAI.rawValue, "customOpenAI")
        XCTAssertEqual(ProviderType.zhipu.rawValue, "zhipu")
        XCTAssertEqual(ProviderType.dashscope.rawValue, "dashscope")
        XCTAssertEqual(ProviderType.minimax.rawValue, "minimax")
    }

    func testProviderTypeAllCasesCount() {
        // There are exactly 9 ProviderType cases. Adding a new one without updating
        // the routing table would break this test as an early warning.
        XCTAssertEqual(
            ProviderType.allCases.count, 9,
            "ProviderType must have exactly 9 cases; update LLMRouter routing if this changes"
        )
    }

    func testLLMProviderTypeComputedPropertyRoundTrips() {
        // Verify that the LLMProvider.type computed property correctly round-trips
        // through providerType (String rawValue) for every known ProviderType.
        for providerType in ProviderType.allCases {
            let provider = LLMProvider(
                name: "Test",
                providerType: providerType,
                baseURL: "https://example.com",
                apiKeyRef: "test-ref"
            )
            XCTAssertEqual(
                provider.type, providerType,
                "LLMProvider.type must round-trip correctly for .\(providerType.rawValue)"
            )
        }
    }

    func testLLMProviderTypeFallsBackToCustomOpenAIForUnknownRawValue() {
        let provider = LLMProvider(
            name: "Unknown",
            providerType: .customOpenAI,  // Start valid
            baseURL: "https://example.com",
            apiKeyRef: "ref"
        )
        // Directly corrupt the raw string to simulate an unknown future value.
        provider.providerType = "unknownFutureProvider"

        XCTAssertEqual(
            provider.type, .customOpenAI,
            "LLMProvider.type must fall back to .customOpenAI for an unrecognised raw value"
        )
    }
}
