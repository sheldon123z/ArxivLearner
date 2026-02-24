import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - PromptVariableEngineTests

final class PromptVariableEngineTests: XCTestCase {

    // MARK: - Container Setup

    /// Creates an in-memory ModelContainer containing every SwiftData model used
    /// by the app so that Paper instances can be inserted and tracked by the
    /// persistence layer during tests.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Paper.self,
            ChatMessage.self,
            LLMProvider.self,
            LLMModel.self,
            PromptTemplate.self,
            UsageRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Returns a fully-populated Paper inserted into the given context.
    private func makePaper(
        in context: ModelContext,
        arxivId: String = "test-001",
        title: String = "Attention Is All You Need",
        authors: [String] = ["Vaswani, A.", "Shazeer, N.", "Parmar, N."],
        abstractText: String = "We propose a new simple network architecture, the Transformer.",
        categories: [String] = ["cs.LG", "cs.CL"],
        markdownContent: String? = "# Attention Is All You Need\n\nFull markdown body."
    ) -> Paper {
        let paper = Paper(
            arxivId: arxivId,
            title: title,
            authors: authors,
            abstractText: abstractText,
            categories: categories,
            pdfURL: "https://arxiv.org/pdf/\(arxivId)",
            markdownContent: markdownContent
        )
        context.insert(paper)
        return paper
    }

    // MARK: - Single Variable Replacement

    func testTitleVariableIsReplaced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "Deep Learning Survey")

        let result = PromptVariableEngine.resolve(
            template: "Title: {{title}}",
            paper: paper
        )

        XCTAssertEqual(result, "Title: Deep Learning Survey")
    }

    func testAbstractVariableIsReplaced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, abstractText: "This paper introduces XYZ.")

        let result = PromptVariableEngine.resolve(
            template: "Abstract: {{abstract}}",
            paper: paper
        )

        XCTAssertEqual(result, "Abstract: This paper introduces XYZ.")
    }

    func testAuthorsVariableIsReplacedWithCommaJoinedList() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, authors: ["Alice", "Bob", "Carol"])

        let result = PromptVariableEngine.resolve(
            template: "Authors: {{authors}}",
            paper: paper
        )

        XCTAssertEqual(result, "Authors: Alice, Bob, Carol")
    }

    func testCategoriesVariableIsReplacedWithCommaJoinedList() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, categories: ["cs.LG", "cs.AI", "stat.ML"])

        let result = PromptVariableEngine.resolve(
            template: "Categories: {{categories}}",
            paper: paper
        )

        XCTAssertEqual(result, "Categories: cs.LG, cs.AI, stat.ML")
    }

    func testFullTextVariableIsReplacedWithMarkdownContent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let markdown = "# Header\n\nSome body text."
        let paper = makePaper(in: context, markdownContent: markdown)

        let result = PromptVariableEngine.resolve(
            template: "Content: {{full_text}}",
            paper: paper
        )

        XCTAssertEqual(result, "Content: \(markdown)")
    }

    func testSelectedTextVariableIsReplacedWhenProvided() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let result = PromptVariableEngine.resolve(
            template: "Selected: {{selected_text}}",
            paper: paper,
            selectedText: "highlighted passage"
        )

        XCTAssertEqual(result, "Selected: highlighted passage")
    }

    // MARK: - Chinese Fallbacks for Missing/Empty Values

    func testEmptyTitleUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "")

        let result = PromptVariableEngine.resolve(
            template: "{{title}}",
            paper: paper
        )

        XCTAssertEqual(result, "(标题不可用)")
    }

    func testWhitespaceTitleUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "   ")

        let result = PromptVariableEngine.resolve(
            template: "{{title}}",
            paper: paper
        )

        XCTAssertEqual(result, "(标题不可用)")
    }

    func testEmptyAbstractUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, abstractText: "")

        let result = PromptVariableEngine.resolve(
            template: "{{abstract}}",
            paper: paper
        )

        XCTAssertEqual(result, "(摘要不可用)")
    }

    func testWhitespaceAbstractUsesChineaseFallback() throws {
        // abstractValue trims .whitespaces (spaces and horizontal tabs only).
        // A string consisting solely of spaces is fully trimmed to empty,
        // so the Chinese fallback is returned.
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, abstractText: "   ")

        let result = PromptVariableEngine.resolve(
            template: "{{abstract}}",
            paper: paper
        )

        XCTAssertEqual(result, "(摘要不可用)")
    }

    func testEmptyAuthorsArrayUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, authors: [])

        let result = PromptVariableEngine.resolve(
            template: "{{authors}}",
            paper: paper
        )

        XCTAssertEqual(result, "(作者信息不可用)")
    }

    func testAuthorsArrayContainingOnlyWhitespaceUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, authors: ["   ", "\t"])

        let result = PromptVariableEngine.resolve(
            template: "{{authors}}",
            paper: paper
        )

        XCTAssertEqual(result, "(作者信息不可用)")
    }

    func testEmptyCategoriesArrayUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, categories: [])

        let result = PromptVariableEngine.resolve(
            template: "{{categories}}",
            paper: paper
        )

        XCTAssertEqual(result, "(分类信息不可用)")
    }

    func testCategoriesArrayContainingOnlyWhitespaceUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, categories: [" ", "  "])

        let result = PromptVariableEngine.resolve(
            template: "{{categories}}",
            paper: paper
        )

        XCTAssertEqual(result, "(分类信息不可用)")
    }

    func testNilMarkdownContentUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, markdownContent: nil)

        let result = PromptVariableEngine.resolve(
            template: "{{full_text}}",
            paper: paper
        )

        XCTAssertEqual(result, "(全文内容不可用)")
    }

    func testEmptyMarkdownContentUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, markdownContent: "")

        let result = PromptVariableEngine.resolve(
            template: "{{full_text}}",
            paper: paper
        )

        XCTAssertEqual(result, "(全文内容不可用)")
    }

    func testWhitespaceOnlyMarkdownContentUsesChineaseFallback() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, markdownContent: "   \n\t  ")

        let result = PromptVariableEngine.resolve(
            template: "{{full_text}}",
            paper: paper
        )

        XCTAssertEqual(result, "(全文内容不可用)")
    }

    // MARK: - Selected Text: nil Produces Empty String

    func testSelectedTextIsEmptyStringWhenNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let result = PromptVariableEngine.resolve(
            template: "Before{{selected_text}}After",
            paper: paper,
            selectedText: nil
        )

        XCTAssertEqual(result, "BeforeAfter")
    }

    func testSelectedTextDefaultParameterIsNil() throws {
        // Calling resolve without the selectedText argument must behave
        // identically to passing nil explicitly.
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let withNilExplicit = PromptVariableEngine.resolve(
            template: "X{{selected_text}}Y",
            paper: paper,
            selectedText: nil
        )
        let withDefaultOmitted = PromptVariableEngine.resolve(
            template: "X{{selected_text}}Y",
            paper: paper
        )

        XCTAssertEqual(withNilExplicit, withDefaultOmitted)
        XCTAssertEqual(withDefaultOmitted, "XY")
    }

    func testSelectedTextEmptyStringIsPreservedAsEmptyString() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let result = PromptVariableEngine.resolve(
            template: "[{{selected_text}}]",
            paper: paper,
            selectedText: ""
        )

        XCTAssertEqual(result, "[]")
    }

    // MARK: - Multiple Variables in the Same Template

    func testAllSixVariablesAreReplacedInSingleTemplate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(
            in: context,
            title: "Test Title",
            authors: ["Author One", "Author Two"],
            abstractText: "Short abstract.",
            categories: ["cs.CV"],
            markdownContent: "# Body"
        )

        let template = """
        Title: {{title}}
        Abstract: {{abstract}}
        Authors: {{authors}}
        Categories: {{categories}}
        Full Text: {{full_text}}
        Selected: {{selected_text}}
        """

        let result = PromptVariableEngine.resolve(
            template: template,
            paper: paper,
            selectedText: "a chosen excerpt"
        )

        XCTAssertTrue(result.contains("Title: Test Title"), "title variable should be replaced")
        XCTAssertTrue(result.contains("Abstract: Short abstract."), "abstract variable should be replaced")
        XCTAssertTrue(result.contains("Authors: Author One, Author Two"), "authors variable should be replaced")
        XCTAssertTrue(result.contains("Categories: cs.CV"), "categories variable should be replaced")
        XCTAssertTrue(result.contains("Full Text: # Body"), "full_text variable should be replaced")
        XCTAssertTrue(result.contains("Selected: a chosen excerpt"), "selected_text variable should be replaced")
    }

    func testDuplicateVariableOccurrencesAreAllReplaced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "Repeat Me")

        let result = PromptVariableEngine.resolve(
            template: "{{title}} and again {{title}}",
            paper: paper
        )

        XCTAssertEqual(result, "Repeat Me and again Repeat Me")
    }

    func testTitleAndAbstractVariablesAreReplacedTogether() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "Paper A", abstractText: "Abstract A")

        let result = PromptVariableEngine.resolve(
            template: "{{title}}: {{abstract}}",
            paper: paper
        )

        XCTAssertEqual(result, "Paper A: Abstract A")
    }

    func testAuthorsAndCategoriesVariablesAreReplacedTogether() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(
            in: context,
            authors: ["Smith, J."],
            categories: ["physics.gen-ph"]
        )

        let result = PromptVariableEngine.resolve(
            template: "By {{authors}} in {{categories}}",
            paper: paper
        )

        XCTAssertEqual(result, "By Smith, J. in physics.gen-ph")
    }

    func testMixedPresentAndMissingVariablesResolveCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // authors and categories are empty, so fallbacks apply.
        let paper = makePaper(
            in: context,
            title: "Valid Title",
            authors: [],
            categories: [],
            markdownContent: nil
        )

        let result = PromptVariableEngine.resolve(
            template: "{{title}} | {{authors}} | {{categories}} | {{full_text}}",
            paper: paper
        )

        XCTAssertEqual(
            result,
            "Valid Title | (作者信息不可用) | (分类信息不可用) | (全文内容不可用)"
        )
    }

    // MARK: - No Variables in Template (Passthrough)

    func testTemplateWithNoVariablesIsReturnedUnchanged() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)
        let template = "Please summarise this paper for me in plain language."

        let result = PromptVariableEngine.resolve(template: template, paper: paper)

        XCTAssertEqual(result, template)
    }

    func testTemplateWithLookAlikePatternIsNotReplaced() throws {
        // Only exact `{{variable}}` patterns are recognised.
        // Single-brace variants and patterns with interior spaces are not matched
        // and pass through untouched.
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context, title: "Attention Is All You Need")

        // {title} and {{ title }} (space-padded) do not match.
        let result = PromptVariableEngine.resolve(
            template: "{title} - {{ title }}",
            paper: paper
        )

        // The literal text should be unchanged because neither pattern matches.
        XCTAssertEqual(result, "{title} - {{ title }}")
        XCTAssertFalse(result.contains("Attention Is All You Need"))
    }

    // MARK: - Empty Template

    func testEmptyTemplateReturnsEmptyString() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let result = PromptVariableEngine.resolve(template: "", paper: paper)

        XCTAssertEqual(result, "")
    }

    func testEmptyTemplateWithSelectedTextReturnsEmptyString() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let paper = makePaper(in: context)

        let result = PromptVariableEngine.resolve(
            template: "",
            paper: paper,
            selectedText: "some selected text"
        )

        XCTAssertEqual(result, "")
    }
}
