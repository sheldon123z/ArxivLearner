import XCTest
@testable import ArxivLearner

// MARK: - ArxivAPIServiceTests

final class ArxivAPIServiceTests: XCTestCase {

    private var service: ArxivAPIService!

    override func setUp() {
        super.setUp()
        service = ArxivAPIService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - testBuildSearchURL

    /// Verifies that the constructed URL contains all required query parameters.
    func testBuildSearchURL() throws {
        let params = ArxivSearchParams(
            query: "transformer",
            category: "cs.LG",
            dateRange: nil,
            sortBy: .submittedDate,
            start: 0,
            maxResults: 25
        )

        let url = try XCTUnwrap(
            service.buildSearchURL(params: params),
            "buildSearchURL should return a non-nil URL for valid params"
        )

        let urlString = url.absoluteString

        // Base endpoint
        XCTAssertTrue(
            urlString.hasPrefix("https://export.arxiv.org/api/query"),
            "URL must target the arXiv API base endpoint"
        )

        // search_query must be present and contain both the free-text and category filter
        XCTAssertTrue(
            urlString.contains("search_query="),
            "URL must include the search_query parameter"
        )
        XCTAssertTrue(
            urlString.contains("transformer"),
            "URL search_query must contain the user query term"
        )
        XCTAssertTrue(
            urlString.contains("cs.LG"),
            "URL search_query must contain the category filter"
        )

        // Pagination parameters
        XCTAssertTrue(
            urlString.contains("start=0"),
            "URL must include the start parameter"
        )
        XCTAssertTrue(
            urlString.contains("max_results=25"),
            "URL must include the max_results parameter"
        )

        // Sort parameter
        XCTAssertTrue(
            urlString.contains("sortBy=submittedDate"),
            "URL must include the sortBy parameter matching ArxivSortBy.submittedDate"
        )

        // Sort order
        XCTAssertTrue(
            urlString.contains("sortOrder=descending"),
            "URL must include the sortOrder parameter"
        )
    }

    /// Verifies that a URL built without a category does not include a spurious cat: fragment.
    func testBuildSearchURL_withoutCategory() throws {
        let params = ArxivSearchParams(
            query: "attention mechanism",
            sortBy: .relevance,
            start: 10,
            maxResults: 5
        )

        let url = try XCTUnwrap(service.buildSearchURL(params: params))
        let urlString = url.absoluteString

        XCTAssertFalse(
            urlString.contains("cat:"),
            "URL must not contain a category filter when none is specified"
        )
        XCTAssertTrue(
            urlString.contains("start=10"),
            "URL must reflect the specified start offset"
        )
        XCTAssertTrue(
            urlString.contains("max_results=5"),
            "URL must reflect the specified maxResults"
        )
    }

    /// Verifies that a date range filter is appended to search_query.
    func testBuildSearchURL_withDateRange() throws {
        let params = ArxivSearchParams(
            query: "diffusion models",
            dateRange: .lastMonth,
            sortBy: .relevance
        )

        let url = try XCTUnwrap(service.buildSearchURL(params: params))
        let urlString = url.absoluteString

        XCTAssertTrue(
            urlString.contains("submittedDate"),
            "URL must include the submittedDate date-range filter when dateRange is specified"
        )
    }

    // MARK: - testParseAtomXML

    /// Parses a minimal Atom XML response and verifies all fields are extracted correctly.
    func testParseAtomXML() throws {
        let sampleXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"
              xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/"
              xmlns:arxiv="http://arxiv.org/schemas/atom">
          <title>ArXiv Query Results</title>
          <id>http://arxiv.org/api/test-feed-id</id>
          <updated>2024-01-15T00:00:00-05:00</updated>
          <opensearch:totalResults>1</opensearch:totalResults>
          <opensearch:startIndex>0</opensearch:startIndex>
          <opensearch:itemsPerPage>10</opensearch:itemsPerPage>
          <entry>
            <id>http://arxiv.org/abs/2301.00001v2</id>
            <published>2023-01-01T00:00:00Z</published>
            <updated>2023-06-01T00:00:00Z</updated>
            <title>Attention Is All You Need: A Revisit</title>
            <summary>We propose a novel architecture based purely on attention
        mechanisms, dispensing with recurrence entirely.</summary>
            <author>
              <name>Alice Researcher</name>
              <arxiv:affiliation>MIT</arxiv:affiliation>
            </author>
            <author>
              <name>Bob Scientist</name>
            </author>
            <category term="cs.LG" scheme="http://arxiv.org/schemas/atom"/>
            <category term="cs.AI" scheme="http://arxiv.org/schemas/atom"/>
            <arxiv:primary_category term="cs.LG" scheme="http://arxiv.org/schemas/atom"/>
            <link rel="alternate" href="http://arxiv.org/abs/2301.00001v2" type="text/html"/>
            <link rel="related" title="pdf" href="http://arxiv.org/pdf/2301.00001v2" type="application/pdf"/>
          </entry>
        </feed>
        """

        let data = try XCTUnwrap(
            sampleXML.data(using: .utf8),
            "Sample XML must be encodable as UTF-8 data"
        )

        let papers = try service.parseResponse(data: data)

        XCTAssertEqual(papers.count, 1, "Parser should extract exactly one paper from the feed")

        let paper = try XCTUnwrap(papers.first)

        // arXiv ID — version suffix must be stripped
        XCTAssertEqual(
            paper.arxivId, "2301.00001",
            "arxivId must be extracted without the version suffix"
        )

        // Title
        XCTAssertEqual(
            paper.title, "Attention Is All You Need: A Revisit",
            "Title must match the <title> element content"
        )

        // Authors
        XCTAssertEqual(paper.authors.count, 2, "Parser must extract both authors")
        XCTAssertEqual(paper.authors[0], "Alice Researcher")
        XCTAssertEqual(paper.authors[1], "Bob Scientist")

        // Abstract — whitespace should be normalized
        XCTAssertTrue(
            paper.abstractText.contains("attention"),
            "Abstract must contain the text from the <summary> element"
        )
        XCTAssertFalse(
            paper.abstractText.hasPrefix(" "),
            "Abstract must be trimmed of leading whitespace"
        )

        // Categories
        XCTAssertEqual(paper.categories.count, 2, "Parser must extract both category terms")
        XCTAssertTrue(paper.categories.contains("cs.LG"), "Categories must include cs.LG")
        XCTAssertTrue(paper.categories.contains("cs.AI"), "Categories must include cs.AI")

        // Published date
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: paper.publishedDate)
        XCTAssertEqual(components.year, 2023, "Published year must be 2023")
        XCTAssertEqual(components.month, 1, "Published month must be January")
        XCTAssertEqual(components.day, 1, "Published day must be 1")

        // PDF URL
        XCTAssertTrue(
            paper.pdfURL.absoluteString.contains("pdf"),
            "PDF URL must reference the pdf endpoint"
        )
        XCTAssertTrue(
            paper.pdfURL.absoluteString.contains("2301.00001"),
            "PDF URL must contain the arXiv identifier"
        )
    }

    /// Verifies that a feed with multiple entries produces the correct number of DTOs.
    func testParseAtomXML_multipleEntries() throws {
        let sampleXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"
              xmlns:arxiv="http://arxiv.org/schemas/atom">
          <entry>
            <id>http://arxiv.org/abs/2301.00001v1</id>
            <published>2023-01-01T00:00:00Z</published>
            <title>Paper One</title>
            <summary>Abstract one.</summary>
            <author><name>Author A</name></author>
            <link rel="related" title="pdf" href="http://arxiv.org/pdf/2301.00001v1" type="application/pdf"/>
          </entry>
          <entry>
            <id>http://arxiv.org/abs/2302.00002v1</id>
            <published>2023-02-01T00:00:00Z</published>
            <title>Paper Two</title>
            <summary>Abstract two.</summary>
            <author><name>Author B</name></author>
            <link rel="related" title="pdf" href="http://arxiv.org/pdf/2302.00002v1" type="application/pdf"/>
          </entry>
        </feed>
        """

        let data = try XCTUnwrap(sampleXML.data(using: .utf8))
        let papers = try service.parseResponse(data: data)

        XCTAssertEqual(papers.count, 2, "Parser should produce one DTO per entry")
        XCTAssertEqual(papers[0].arxivId, "2301.00001")
        XCTAssertEqual(papers[1].arxivId, "2302.00002")
    }

    /// Verifies that when no pdf link is present, a fallback PDF URL is derived from the arxivId.
    func testParseAtomXML_fallbackPDFURL() throws {
        let sampleXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2305.12345v1</id>
            <published>2023-05-01T00:00:00Z</published>
            <title>No PDF Link Paper</title>
            <summary>An abstract.</summary>
            <author><name>Author X</name></author>
            <link rel="alternate" href="http://arxiv.org/abs/2305.12345v1" type="text/html"/>
          </entry>
        </feed>
        """

        let data = try XCTUnwrap(sampleXML.data(using: .utf8))
        let papers = try service.parseResponse(data: data)

        XCTAssertEqual(papers.count, 1)
        let paper = try XCTUnwrap(papers.first)
        XCTAssertTrue(
            paper.pdfURL.absoluteString.contains("2305.12345"),
            "Fallback PDF URL must include the arxiv ID"
        )
    }
}
