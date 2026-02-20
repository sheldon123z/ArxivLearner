import Foundation

// MARK: - ArxivDateRange

enum ArxivDateRange {
    case lastWeek
    case lastMonth
    case lastThreeMonths
    case lastYear

    /// Returns a date filter string suitable for use as an arXiv search_query modifier.
    /// arXiv does not expose a native date-range parameter, so we compute the ISO-8601
    /// submission date range using the submittedDate field query prefix.
    var queryFragment: String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let startDate: Date

        switch self {
        case .lastWeek:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastThreeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .lastYear:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let start = formatter.string(from: startDate)
        let end = formatter.string(from: now)
        return "submittedDate:[\(start)0000+TO+\(end)2359]"
    }
}

// MARK: - ArxivSortBy

enum ArxivSortBy: String {
    case relevance = "relevance"
    case lastUpdatedDate = "lastUpdatedDate"
    case submittedDate = "submittedDate"
}

// MARK: - ArxivSearchParams

struct ArxivSearchParams {
    /// Free-text or field-prefixed query, e.g. "ti:transformer" or "cat:cs.AI".
    let query: String

    /// Optional arXiv category filter, e.g. "cs.LG".
    let category: String?

    /// Optional date range limiting results to a recent period.
    let dateRange: ArxivDateRange?

    /// Field by which results are sorted.
    let sortBy: ArxivSortBy

    /// Zero-based offset for pagination.
    let start: Int

    /// Maximum number of results to return (capped at 2000 by arXiv).
    let maxResults: Int

    init(
        query: String,
        category: String? = nil,
        dateRange: ArxivDateRange? = nil,
        sortBy: ArxivSortBy = .relevance,
        start: Int = 0,
        maxResults: Int = 20
    ) {
        self.query = query
        self.category = category
        self.dateRange = dateRange
        self.sortBy = sortBy
        self.start = start
        self.maxResults = maxResults
    }
}

// MARK: - ArxivPaperDTO

struct ArxivPaperDTO {
    /// The arXiv identifier extracted from the entry <id> URL, e.g. "2301.00001".
    let arxivId: String

    /// Paper title with whitespace normalized.
    let title: String

    /// Ordered list of author names.
    let authors: [String]

    /// Full abstract text with whitespace normalized.
    let abstractText: String

    /// All category terms listed in <category> elements.
    let categories: [String]

    /// Date of the first submission (v1).
    let publishedDate: Date

    /// Direct URL to the PDF version on arxiv.org.
    let pdfURL: URL
}

// MARK: - ArxivAPIError

enum ArxivAPIError: Error, LocalizedError {
    case invalidURL
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to construct a valid arXiv API URL."
        case .parsingFailed(let detail):
            return "Failed to parse arXiv API response: \(detail)"
        }
    }
}

// MARK: - ArxivAPIService

final class ArxivAPIService {

    // MARK: Constants

    private static let baseURLString = "https://export.arxiv.org/api/query"

    // MARK: Dependencies

    private let httpClient: HTTPClient

    // MARK: Init

    init(httpClient: HTTPClient = .shared) {
        self.httpClient = httpClient
    }

    // MARK: Public API

    /// Searches arXiv with the given parameters and returns parsed paper DTOs.
    func search(params: ArxivSearchParams) async throws -> [ArxivPaperDTO] {
        guard let url = buildSearchURL(params: params) else {
            throw ArxivAPIError.invalidURL
        }
        let data = try await httpClient.fetch(url: url)
        return try parseResponse(data: data)
    }

    /// Builds the arXiv query URL from the given search parameters.
    /// Returns nil only when URLComponents cannot be constructed from the base URL.
    func buildSearchURL(params: ArxivSearchParams) -> URL? {
        guard var components = URLComponents(string: Self.baseURLString) else {
            return nil
        }

        // Compose the search_query value.
        var queryParts: [String] = []

        if !params.query.isEmpty {
            queryParts.append("all:\(params.query)")
        }

        if let category = params.category {
            queryParts.append("cat:\(category)")
        }

        if let dateRange = params.dateRange {
            queryParts.append(dateRange.queryFragment)
        }

        let searchQuery = queryParts.joined(separator: "+AND+")

        components.queryItems = [
            URLQueryItem(name: "search_query", value: searchQuery),
            URLQueryItem(name: "start", value: String(params.start)),
            URLQueryItem(name: "max_results", value: String(params.maxResults)),
            URLQueryItem(name: "sortBy", value: params.sortBy.rawValue),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]

        return components.url
    }

    /// Parses the raw Atom XML data returned by the arXiv API.
    func parseResponse(data: Data) throws -> [ArxivPaperDTO] {
        let parser = ArxivXMLParser()
        return try parser.parse(data: data)
    }
}

// MARK: - ArxivXMLParser

/// SAX-style XML parser that converts an arXiv Atom feed into an array of ArxivPaperDTO.
final class ArxivXMLParser: NSObject, XMLParserDelegate {

    // MARK: Private State

    // Currently parsed entry fields
    private var papers: [ArxivPaperDTO] = []
    private var parseError: Error?

    // Per-entry accumulation
    private var currentTitle: String = ""
    private var currentId: String = ""
    private var currentAbstract: String = ""
    private var currentPublishedString: String = ""
    private var currentAuthors: [String] = []
    private var currentCategories: [String] = []
    private var currentPDFURLString: String = ""
    private var currentAuthorName: String = ""

    // Element tracking
    private var insideEntry: Bool = false
    private var currentElement: String = ""
    private var insideAuthor: Bool = false

    // Date formatter matching arXiv ISO-8601 timestamps (e.g. 2023-01-15T00:00:00Z)
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let dateFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: Public API

    func parse(data: Data) throws -> [ArxivPaperDTO] {
        papers = []
        parseError = nil

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()

        if let error = parseError {
            throw error
        }

        return papers
    }

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        switch elementName {
        case "entry":
            insideEntry = true
            currentTitle = ""
            currentId = ""
            currentAbstract = ""
            currentPublishedString = ""
            currentAuthors = []
            currentCategories = []
            currentPDFURLString = ""
            currentAuthorName = ""
            insideAuthor = false

        case "author":
            if insideEntry {
                insideAuthor = true
                currentAuthorName = ""
            }

        case "category":
            if insideEntry, let term = attributeDict["term"] {
                currentCategories.append(term)
            }

        case "link":
            if insideEntry {
                let title = attributeDict["title"] ?? ""
                let rel = attributeDict["rel"] ?? ""
                let href = attributeDict["href"] ?? ""

                // Prefer the explicit title="pdf" link; fall back to constructing from the
                // abstract URL when the pdf link is absent (older entries).
                if title == "pdf" || rel == "related" && title == "pdf" {
                    currentPDFURLString = href
                }
            }

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        guard insideEntry else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "id":
            currentId += string
        case "summary":
            currentAbstract += string
        case "published":
            currentPublishedString += string
        case "name":
            if insideAuthor {
                currentAuthorName += string
            }
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "author":
            if insideEntry && insideAuthor {
                let name = currentAuthorName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    currentAuthors.append(name)
                }
                insideAuthor = false
                currentAuthorName = ""
            }

        case "entry":
            finalizeCurrentEntry()
            insideEntry = false

        default:
            break
        }

        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = ArxivAPIError.parsingFailed(parseError.localizedDescription)
    }

    // MARK: Private Helpers

    private func finalizeCurrentEntry() {
        // --- Extract arXiv ID from the <id> URL ---
        // Format: http://arxiv.org/abs/2301.00001v2  or  http://arxiv.org/abs/hep-ex/0307015
        let rawId = currentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let arxivId: String
        if let absRange = rawId.range(of: "/abs/") {
            let idWithVersion = String(rawId[absRange.upperBound...])
            // Strip trailing version suffix vN
            if let vRange = idWithVersion.range(of: #"v\d+$"#, options: .regularExpression) {
                arxivId = String(idWithVersion[..<vRange.lowerBound])
            } else {
                arxivId = idWithVersion
            }
        } else {
            arxivId = rawId
        }

        guard !arxivId.isEmpty else { return }

        // --- Normalize title ---
        let title = currentTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // --- Normalize abstract ---
        let abstract = currentAbstract
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // --- Parse published date ---
        let publishedRaw = currentPublishedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let publishedDate = dateFormatter.date(from: publishedRaw)
            ?? dateFormatterNoFraction.date(from: publishedRaw)
            ?? Date()

        // --- Resolve PDF URL ---
        // If no pdf link was found in <link title="pdf">, derive it from the abstract URL.
        let pdfURLString: String
        if !currentPDFURLString.isEmpty {
            pdfURLString = currentPDFURLString
        } else {
            pdfURLString = "https://arxiv.org/pdf/\(arxivId)"
        }

        guard let pdfURL = URL(string: pdfURLString) else { return }

        let dto = ArxivPaperDTO(
            arxivId: arxivId,
            title: title,
            authors: currentAuthors,
            abstractText: abstract,
            categories: currentCategories,
            publishedDate: publishedDate,
            pdfURL: pdfURL
        )

        papers.append(dto)
    }
}
