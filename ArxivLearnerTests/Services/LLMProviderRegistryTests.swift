import XCTest
@testable import ArxivLearner

final class LLMProviderRegistryTests: XCTestCase {

    func testAllProvidersCount() {
        XCTAssertEqual(LLMProviderRegistry.allProviders.count, 8)
    }

    func testProviderIds() {
        let ids = LLMProviderRegistry.allProviders.map(\.id)
        XCTAssertTrue(ids.contains("openai"))
        XCTAssertTrue(ids.contains("anthropic"))
        XCTAssertTrue(ids.contains("google"))
        XCTAssertTrue(ids.contains("deepseek"))
        XCTAssertTrue(ids.contains("zhipu"))
        XCTAssertTrue(ids.contains("dashscope"))
        XCTAssertTrue(ids.contains("minimax"))
        XCTAssertTrue(ids.contains("openrouter"))
    }

    func testProviderLookupById() {
        let deepseek = LLMProviderRegistry.provider(id: "deepseek")
        XCTAssertNotNil(deepseek)
        XCTAssertEqual(deepseek?.name, "DeepSeek")
        XCTAssertEqual(deepseek?.baseURL, "https://api.deepseek.com/v1")
    }

    func testProviderLookupNotFound() {
        XCTAssertNil(LLMProviderRegistry.provider(id: "unknown"))
    }

    func testAllProvidersHaveModels() {
        for provider in LLMProviderRegistry.allProviders {
            XCTAssertGreaterThanOrEqual(
                provider.models.count, 2,
                "\(provider.name) should have at least 2 preset models"
            )
        }
    }

    func testOpenRouterSupportsModelDiscovery() {
        let openRouter = LLMProviderRegistry.provider(id: "openrouter")
        XCTAssertNotNil(openRouter)
        XCTAssertTrue(openRouter!.supportsModelDiscovery)
    }

    func testOtherProvidersDoNotSupportModelDiscovery() {
        let others = LLMProviderRegistry.allProviders.filter { $0.id != "openrouter" }
        for provider in others {
            XCTAssertFalse(
                provider.supportsModelDiscovery,
                "\(provider.name) should not support model discovery"
            )
        }
    }

    func testModelIdsUniqueWithinProvider() {
        for provider in LLMProviderRegistry.allProviders {
            let ids = provider.models.map(\.id)
            XCTAssertEqual(
                ids.count, Set(ids).count,
                "\(provider.name) has duplicate model IDs"
            )
        }
    }
}
