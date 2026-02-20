import XCTest
@testable import ArxivLearner

final class LLMServiceTests: XCTestCase {

    // MARK: - testBuildChatRequest

    func testBuildChatRequest() throws {
        let config = LLMProviderConfig(
            name: "Test Provider",
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test-12345",
            modelId: "gpt-4o"
        )
        let service = OpenAICompatibleService(config: config)
        let messages = [LLMMessage(role: "user", content: "Hello")]

        let request = try service.buildRequest(messages: messages, stream: false)

        // Verify the URL points to the chat completions endpoint.
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions",
            "Request URL should be base URL + /chat/completions"
        )

        // Verify HTTP method is POST.
        XCTAssertEqual(request.httpMethod, "POST", "HTTP method must be POST")

        // Verify the Authorization header uses the Bearer scheme with the correct API key.
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer sk-test-12345",
            "Authorization header should be 'Bearer <apiKey>'"
        )

        // Verify Content-Type is set for JSON body.
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json",
            "Content-Type header should be 'application/json'"
        )

        // Verify the request body is non-empty.
        XCTAssertNotNil(request.httpBody, "Request body must not be nil")
    }

    func testBuildChatRequestStripsTrailingSlash() throws {
        // Base URLs that end with "/" should still produce a clean endpoint path.
        let config = LLMProviderConfig(
            name: "Trailing Slash Provider",
            baseURL: "https://api.openai.com/v1/",
            apiKey: "sk-test",
            modelId: "gpt-4o-mini"
        )
        let service = OpenAICompatibleService(config: config)
        let request = try service.buildRequest(messages: [], stream: true)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions",
            "Trailing slash in baseURL should be stripped before appending the path"
        )
    }

    func testBuildChatRequestThrowsOnInvalidURL() {
        let config = LLMProviderConfig(
            name: "Bad URL Provider",
            baseURL: "not a valid url !!!",
            apiKey: "key",
            modelId: "model"
        )
        let service = OpenAICompatibleService(config: config)

        XCTAssertThrowsError(
            try service.buildRequest(messages: [], stream: false)
        ) { error in
            XCTAssertEqual(error as? LLMError, .invalidURL)
        }
    }

    // MARK: - testContextBuilderPrefersMarkdown

    func testContextBuilderPrefersMarkdown() {
        let paper = ContextBuilder.PaperContext(
            title: "Test Paper",
            abstractText: "This is the abstract.",
            markdownContent: "# Full Markdown Content",
            fullText: "Full plain text content."
        )

        let context = ContextBuilder.buildContext(for: paper)

        XCTAssertTrue(
            context.contains("# Full Markdown Content"),
            "Context should use markdownContent when it is available"
        )
        XCTAssertFalse(
            context.contains("Full plain text content."),
            "Context should not use fullText when markdownContent is present"
        )
        XCTAssertFalse(
            context.contains("This is the abstract."),
            "Context should not use abstract when markdownContent is present"
        )
    }

    func testContextBuilderPrefersFullTextOverAbstract() {
        let paper = ContextBuilder.PaperContext(
            title: "Test Paper",
            abstractText: "This is the abstract.",
            markdownContent: nil,
            fullText: "Full plain text content."
        )

        let context = ContextBuilder.buildContext(for: paper)

        XCTAssertTrue(
            context.contains("Full plain text content."),
            "Context should use fullText when markdownContent is nil"
        )
        XCTAssertFalse(
            context.contains("This is the abstract."),
            "Context should not use abstract when fullText is available"
        )
    }

    // MARK: - testContextBuilderFallsBackToAbstract

    func testContextBuilderFallsBackToAbstract() {
        let paper = ContextBuilder.PaperContext(
            title: "Test Paper",
            abstractText: "This is the abstract.",
            markdownContent: nil,
            fullText: nil
        )

        let context = ContextBuilder.buildContext(for: paper)

        XCTAssertTrue(
            context.contains("This is the abstract."),
            "Context should fall back to abstract when both markdownContent and fullText are nil"
        )
    }

    func testContextBuilderFallsBackToAbstractWhenMarkdownIsEmpty() {
        let paper = ContextBuilder.PaperContext(
            title: "Test Paper",
            abstractText: "Abstract text here.",
            markdownContent: "",
            fullText: ""
        )

        let context = ContextBuilder.buildContext(for: paper)

        XCTAssertTrue(
            context.contains("Abstract text here."),
            "Context should fall back to abstract when markdownContent and fullText are empty strings"
        )
    }

    func testContextBuilderIncludesTitle() {
        let paper = ContextBuilder.PaperContext(
            title: "Attention Is All You Need",
            abstractText: "Abstract.",
            markdownContent: nil,
            fullText: nil
        )

        let context = ContextBuilder.buildContext(for: paper)

        XCTAssertTrue(
            context.contains("Attention Is All You Need"),
            "Context should always include the paper title"
        )
    }

    // MARK: - insightSystemPrompt

    func testInsightSystemPromptIsNonEmpty() {
        let prompt = ContextBuilder.insightSystemPrompt()
        XCTAssertFalse(prompt.isEmpty, "System prompt must not be empty")
    }

    func testInsightSystemPromptIsChinese() {
        let prompt = ContextBuilder.insightSystemPrompt()
        // The prompt must contain Chinese characters.
        let hasChinese = prompt.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        XCTAssertTrue(hasChinese, "System prompt should contain Chinese text")
    }
}
