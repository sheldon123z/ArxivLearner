import XCTest
@testable import ArxivLearner

final class LLMProviderConfigTests: XCTestCase {

    func testEncodeDecode() throws {
        let config = LLMProviderConfig(
            providerId: "openai",
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test",
            modelId: "gpt-4o"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMProviderConfig.self, from: data)

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.providerId, "openai")
    }

    func testBackwardCompatibility_oldDataWithoutProviderId() throws {
        // Simulate old config JSON that does NOT have providerId
        let oldJSON = """
        {
            "name": "OpenAI",
            "baseURL": "https://api.openai.com/v1",
            "apiKey": "sk-old",
            "modelId": "gpt-4"
        }
        """
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LLMProviderConfig.self, from: data)

        XCTAssertNil(decoded.providerId)
        XCTAssertEqual(decoded.name, "OpenAI")
        XCTAssertEqual(decoded.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(decoded.apiKey, "sk-old")
        XCTAssertEqual(decoded.modelId, "gpt-4")
    }

    func testCustomConfigHasNilProviderId() {
        let config = LLMProviderConfig(
            name: "Custom",
            baseURL: "https://custom.api.com/v1",
            apiKey: "key",
            modelId: "model"
        )
        XCTAssertNil(config.providerId)
    }

    func testProviderIdPreservedThroughRoundTrip() throws {
        let config = LLMProviderConfig(
            providerId: "deepseek",
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            apiKey: "ds-key",
            modelId: "deepseek-chat"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMProviderConfig.self, from: data)

        XCTAssertEqual(decoded.providerId, "deepseek")
    }
}
