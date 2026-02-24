import XCTest
@testable import ArxivLearner

final class OpenRouterModelServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(
        data: Data,
        statusCode: Int = 200
    ) -> URLSession {
        let response = HTTPURLResponse(
            url: URL(string: "https://openrouter.ai/api/v1/models")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        MockURLProtocol.mockData = data
        MockURLProtocol.mockResponse = response
        MockURLProtocol.mockError = nil

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeErrorSession() -> URLSession {
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    // MARK: - Tests

    func testFetchModelsSuccess() async throws {
        let json = """
        {
            "data": [
                {"id": "openai/gpt-4o", "name": "GPT-4o"},
                {"id": "anthropic/claude-sonnet-4", "name": "Claude Sonnet 4"}
            ]
        }
        """
        let session = makeSession(data: json.data(using: .utf8)!)
        let service = OpenRouterModelService(session: session)

        let models = try await service.fetchModels()

        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].id, "openai/gpt-4o")
        XCTAssertEqual(models[0].name, "GPT-4o")
        XCTAssertEqual(models[1].id, "anthropic/claude-sonnet-4")
    }

    func testFetchModelsBadStatusCode() async {
        let session = makeSession(data: Data(), statusCode: 500)
        let service = OpenRouterModelService(session: session)

        do {
            _ = try await service.fetchModels()
            XCTFail("Expected error")
        } catch let error as LLMError {
            if case .badResponse(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected badResponse error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsInvalidJSON() async {
        let session = makeSession(data: "not json".data(using: .utf8)!)
        let service = OpenRouterModelService(session: session)

        do {
            _ = try await service.fetchModels()
            XCTFail("Expected error")
        } catch let error as LLMError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponse error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFallbackModelsNotEmpty() {
        XCTAssertGreaterThanOrEqual(OpenRouterModelService.fallbackModels.count, 3)
    }

    func testFallbackModelsContainExpectedIds() {
        let ids = OpenRouterModelService.fallbackModels.map(\.id)
        XCTAssertTrue(ids.contains("anthropic/claude-sonnet-4"))
        XCTAssertTrue(ids.contains("openai/gpt-4o"))
        XCTAssertTrue(ids.contains("google/gemini-2.5-pro-preview"))
    }
}

// MARK: - MockURLProtocol

private class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = Self.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = Self.mockData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
