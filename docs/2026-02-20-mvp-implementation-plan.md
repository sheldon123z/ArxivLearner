# ArxivLearner MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a working iOS app that searches arXiv, displays papers as flippable cards, downloads PDFs, converts to Markdown via doc2x, and generates LLM-powered insights.

**Architecture:** SwiftUI single-module app with MVVM pattern, organized by Feature folders. Service layer abstracts arXiv API, doc2x, and LLM calls. SwiftData for persistence, Keychain for API keys, FileManager for PDF/Markdown caching.

**Tech Stack:** SwiftUI (iOS 17+), SwiftData, PDFKit, URLSession + async/await, XcodeGen for project generation

**Implementation Constraint:** All third-party APIs (arXiv, doc2x, OpenAI) MUST be implemented by first searching their latest documentation. Use Agent Teams for parallel development.

---

## Agent Team Structure

The following tasks are designed for parallel agent team execution:

```
Team Lead ─── coordinates all agents
    │
    ├── Agent A: Foundation ──── Task 1-4 (project setup, models, theme, keychain)
    │
    ├── Agent B: arXiv + Search ── Task 5, 9 (arXiv API, search UI)
    │       depends on: Task 2 (models)
    │
    ├── Agent C: PDF Pipeline ──── Task 6, 7, 10 (PDF cache, reader, doc2x)
    │       depends on: Task 2 (models)
    │
    ├── Agent D: LLM Engine ────── Task 8, 11 (LLM service, insight generation)
    │       depends on: Task 2 (models), Task 4 (keychain)
    │
    ├── Agent E: Card UI ────────── Task 12, 13 (compact card, full card + flip)
    │       depends on: Task 2 (models), Task 3 (theme)
    │
    └── Agent F: Shell + Settings ─ Task 14, 15, 16 (library, settings, app shell)
            depends on: Task 2 (models)
```

**Dependency order:** Task 1 → Tasks 2,3,4 (parallel) → All other tasks (parallel by agent)

---

## Task 1: Project Scaffolding

**Files:**
- Create: `project.yml` (XcodeGen spec)
- Create: full directory structure

**Step 1: Install XcodeGen if needed**

Run: `brew list xcodegen || brew install xcodegen`

**Step 2: Create directory structure**

```bash
cd /Users/xiaodongzheng/exps/ArxivLearner
mkdir -p ArxivLearner/{App,Core/{Network,LLM,Services,Storage/Models,Keychain},Features/{Search,Cards,Reader,Chat,Library,Settings},Shared/{Theme,Components,Extensions},Resources}
mkdir -p ArxivLearnerTests
```

**Step 3: Create XcodeGen project spec**

Create `project.yml`:

```yaml
name: ArxivLearner
options:
  bundleIdPrefix: com.arxivlearner
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  groupSortPosition: top
settings:
  base:
    SWIFT_VERSION: "5.9"
    TARGETED_DEVICE_FAMILY: "1"
targets:
  ArxivLearner:
    type: application
    platform: iOS
    sources:
      - path: ArxivLearner
    settings:
      base:
        INFOPLIST_FILE: ArxivLearner/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.arxivlearner.app
        CODE_SIGN_STYLE: Automatic
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    info:
      path: ArxivLearner/Info.plist
      properties:
        CFBundleDisplayName: ArxivLearner
        UILaunchScreen: {}
        NSAppTransportSecurity:
          NSAllowsArbitraryLoads: true
  ArxivLearnerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ArxivLearnerTests
    dependencies:
      - target: ArxivLearner
    settings:
      base:
        INFOPLIST_FILE: ArxivLearnerTests/Info.plist
```

**Step 4: Create App entry point**

Create `ArxivLearner/App/ArxivLearnerApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ArxivLearnerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Paper.self, ChatMessage.self])
    }
}
```

Create `ArxivLearner/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("ArxivLearner")
    }
}

#Preview {
    ContentView()
}
```

**Step 5: Generate Xcode project and verify build**

```bash
cd /Users/xiaodongzheng/exps/ArxivLearner
xcodegen generate
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

**Step 6: Initialize git and commit**

```bash
cd /Users/xiaodongzheng/exps/ArxivLearner
git init
cat > .gitignore << 'EOF'
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
.build/
*.swp
*.DS_Store
EOF
git add -A
git commit -m "chore: scaffold ArxivLearner iOS project with XcodeGen"
```

---

## Task 2: SwiftData Models

**Files:**
- Create: `ArxivLearner/Core/Storage/Models/Paper.swift`
- Create: `ArxivLearner/Core/Storage/Models/LLMProviderModel.swift`
- Create: `ArxivLearner/Core/Storage/Models/ChatMessage.swift`
- Test: `ArxivLearnerTests/Models/PaperTests.swift`

**Step 1: Write Paper model tests**

Create `ArxivLearnerTests/Models/PaperTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ArxivLearner

final class PaperTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Paper.self,
            configurations: config
        )
    }

    func testPaperCreation() {
        let context = container.mainContext
        let paper = Paper(
            arxivId: "2401.12345",
            title: "Test Paper",
            authors: ["Author A", "Author B"],
            abstractText: "This is a test abstract.",
            categories: ["cs.AI"],
            publishedDate: Date(),
            pdfURL: "https://arxiv.org/pdf/2401.12345"
        )
        context.insert(paper)
        try! context.save()

        let fetched = try! context.fetch(FetchDescriptor<Paper>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.arxivId, "2401.12345")
        XCTAssertEqual(fetched.first?.isFavorite, false)
        XCTAssertEqual(fetched.first?.markdownConvertStatus, .none)
    }

    func testToggleFavorite() {
        let paper = Paper(
            arxivId: "2401.99999",
            title: "Favorite Test",
            authors: ["Author"],
            abstractText: "Abstract",
            categories: ["cs.LG"],
            publishedDate: Date(),
            pdfURL: "https://arxiv.org/pdf/2401.99999"
        )
        XCTAssertFalse(paper.isFavorite)
        paper.isFavorite = true
        XCTAssertTrue(paper.isFavorite)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test|error|FAIL)"
```

Expected: FAIL — Paper type not found

**Step 3: Implement Paper model**

Create `ArxivLearner/Core/Storage/Models/Paper.swift`:

```swift
import Foundation
import SwiftData

enum ConvertStatus: String, Codable {
    case none
    case converting
    case completed
    case failed
}

@Model
final class Paper {
    @Attribute(.unique) var arxivId: String
    var title: String
    var authors: [String]
    var abstractText: String
    var categories: [String]
    var publishedDate: Date
    var pdfURL: String
    var pdfLocalPath: String?
    var isDownloaded: Bool
    var isFavorite: Bool
    var tags: [String]
    var llmInsight: String?
    var markdownContent: String?
    var markdownConvertStatus: ConvertStatus
    var markdownConvertedAt: Date?
    var createdAt: Date

    init(
        arxivId: String,
        title: String,
        authors: [String],
        abstractText: String,
        categories: [String],
        publishedDate: Date,
        pdfURL: String,
        pdfLocalPath: String? = nil,
        isDownloaded: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = [],
        llmInsight: String? = nil,
        markdownContent: String? = nil,
        markdownConvertStatus: ConvertStatus = .none,
        markdownConvertedAt: Date? = nil
    ) {
        self.arxivId = arxivId
        self.title = title
        self.authors = authors
        self.abstractText = abstractText
        self.categories = categories
        self.publishedDate = publishedDate
        self.pdfURL = pdfURL
        self.pdfLocalPath = pdfLocalPath
        self.isDownloaded = isDownloaded
        self.isFavorite = isFavorite
        self.tags = tags
        self.llmInsight = llmInsight
        self.markdownContent = markdownContent
        self.markdownConvertStatus = markdownConvertStatus
        self.markdownConvertedAt = markdownConvertedAt
        self.createdAt = Date()
    }
}
```

**Step 4: Implement ChatMessage model**

Create `ArxivLearner/Core/Storage/Models/ChatMessage.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ChatMessage {
    var paper: Paper?
    var role: String
    var content: String
    var timestamp: Date

    init(role: String, content: String, paper: Paper? = nil) {
        self.role = role
        self.content = content
        self.paper = paper
        self.timestamp = Date()
    }
}
```

**Step 5: Implement LLM Provider/Model types (lightweight for MVP)**

Create `ArxivLearner/Core/Storage/Models/LLMProviderModel.swift`:

```swift
import Foundation

struct LLMProviderConfig: Codable {
    var name: String
    var baseURL: String
    var apiKey: String
    var modelId: String
}
```

Note: MVP uses a single simple config stored in UserDefaults. Full SwiftData LLMProvider/LLMModel models are Phase 2.

**Step 6: Run tests and verify pass**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS

**Step 7: Commit**

```bash
git add ArxivLearner/Core/Storage/Models/ ArxivLearnerTests/Models/
git commit -m "feat: add SwiftData models for Paper, ChatMessage, LLMProviderConfig"
```

---

## Task 3: App Theme & Shared Components

**Files:**
- Create: `ArxivLearner/Shared/Theme/AppTheme.swift`
- Create: `ArxivLearner/Shared/Components/TagChip.swift`
- Create: `ArxivLearner/Shared/Components/LoadingOverlay.swift`

**Step 1: Create AppTheme**

Create `ArxivLearner/Shared/Theme/AppTheme.swift`:

```swift
import SwiftUI

enum AppTheme {
    // MARK: - Colors
    enum Colors {
        static let primary = Color(hex: "6C5CE7")
        static let secondary = Color(hex: "00CEC9")
        static let accent = Color(hex: "FD79A8")
        static let background = Color(.systemGroupedBackground)
        static let cardBackground = Color(.systemBackground)
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)

        static let categoryColors: [String: Color] = [
            "cs.AI": Color(hex: "6C5CE7"),
            "cs.LG": Color(hex: "00CEC9"),
            "cs.CV": Color(hex: "FD79A8"),
            "cs.CL": Color(hex: "FDCB6E"),
            "cs.RO": Color(hex: "E17055"),
        ]

        static func categoryColor(for category: String) -> Color {
            categoryColors[category] ?? Color(hex: "636E72")
        }
    }

    // MARK: - Dimensions
    enum Dimensions {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardShadowRadius: CGFloat = 8
        static let compactCardHeight: CGFloat = 120
        static let buttonCornerRadius: CGFloat = 10
        static let spacing: CGFloat = 12
    }

    // MARK: - Card Shadow
    static let cardShadow = ShadowStyle.drop(
        color: .black.opacity(0.1),
        radius: 8,
        x: 0,
        y: 4
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
```

**Step 2: Create TagChip component**

Create `ArxivLearner/Shared/Components/TagChip.swift`:

```swift
import SwiftUI

struct TagChip: View {
    let text: String
    var color: Color = AppTheme.Colors.primary

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        TagChip(text: "cs.AI")
        TagChip(text: "cs.LG", color: AppTheme.Colors.secondary)
    }
}
```

**Step 3: Create LoadingOverlay**

Create `ArxivLearner/Shared/Components/LoadingOverlay.swift`:

```swift
import SwiftUI

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    LoadingOverlay(message: "正在生成见解...")
}
```

**Step 4: Verify build**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ArxivLearner/Shared/
git commit -m "feat: add AppTheme, TagChip, LoadingOverlay shared components"
```

---

## Task 4: Keychain Service

**Files:**
- Create: `ArxivLearner/Core/Keychain/KeychainService.swift`
- Test: `ArxivLearnerTests/Services/KeychainServiceTests.swift`

**Step 1: Write failing test**

Create `ArxivLearnerTests/Services/KeychainServiceTests.swift`:

```swift
import XCTest
@testable import ArxivLearner

final class KeychainServiceTests: XCTestCase {
    let service = KeychainService.shared

    override func tearDown() {
        super.tearDown()
        try? service.delete(key: "test_api_key")
    }

    func testSaveAndRetrieve() throws {
        try service.save(key: "test_api_key", value: "sk-abc123")
        let retrieved = try service.retrieve(key: "test_api_key")
        XCTAssertEqual(retrieved, "sk-abc123")
    }

    func testDelete() throws {
        try service.save(key: "test_api_key", value: "sk-abc123")
        try service.delete(key: "test_api_key")
        let retrieved = try? service.retrieve(key: "test_api_key")
        XCTAssertNil(retrieved)
    }

    func testUpdate() throws {
        try service.save(key: "test_api_key", value: "old-value")
        try service.save(key: "test_api_key", value: "new-value")
        let retrieved = try service.retrieve(key: "test_api_key")
        XCTAssertEqual(retrieved, "new-value")
    }
}
```

**Step 2: Implement KeychainService**

Create `ArxivLearner/Core/Keychain/KeychainService.swift`:

```swift
import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.arxivlearner.app"

    private init() {}

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        // Delete existing
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.retrieveFailed(status)
        }
        return string
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
}
```

**Step 3: Run tests**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/KeychainServiceTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS

**Step 4: Commit**

```bash
git add ArxivLearner/Core/Keychain/ ArxivLearnerTests/Services/
git commit -m "feat: add KeychainService for secure API key storage"
```

---

## Task 5: arXiv API Service

**Files:**
- Create: `ArxivLearner/Core/Network/ArxivAPIService.swift`
- Create: `ArxivLearner/Core/Network/HTTPClient.swift`
- Test: `ArxivLearnerTests/Services/ArxivAPIServiceTests.swift`

**IMPORTANT:** Before implementing, search the latest arXiv API documentation to confirm endpoint format, query parameters, rate limits, and response XML schema.

**Step 1: Create HTTPClient**

Create `ArxivLearner/Core/Network/HTTPClient.swift`:

```swift
import Foundation

final class HTTPClient {
    static let shared = HTTPClient()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.badResponse
        }
        return data
    }

    func fetch(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.badResponse
        }
        return data
    }
}

enum HTTPError: Error {
    case badResponse
    case invalidURL
}
```

**Step 2: Write arXiv service tests**

Create `ArxivLearnerTests/Services/ArxivAPIServiceTests.swift`:

```swift
import XCTest
@testable import ArxivLearner

final class ArxivAPIServiceTests: XCTestCase {
    func testBuildSearchURL() {
        let service = ArxivAPIService()
        let params = ArxivSearchParams(
            query: "reinforcement learning",
            category: "cs.AI",
            sortBy: .relevance,
            start: 0,
            maxResults: 20
        )
        let url = service.buildSearchURL(params: params)
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("search_query="))
        XCTAssertTrue(urlString.contains("max_results=20"))
    }

    func testParseAtomXML() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2401.12345v1</id>
            <title>Test Paper Title</title>
            <summary>This is a test abstract.</summary>
            <published>2024-01-15T00:00:00Z</published>
            <author><name>Author A</name></author>
            <author><name>Author B</name></author>
            <category term="cs.AI"/>
            <link href="http://arxiv.org/pdf/2401.12345v1" title="pdf" type="application/pdf"/>
          </entry>
        </feed>
        """
        let service = ArxivAPIService()
        let papers = try service.parseResponse(data: xml.data(using: .utf8)!)
        XCTAssertEqual(papers.count, 1)
        XCTAssertEqual(papers.first?.arxivId, "2401.12345")
        XCTAssertEqual(papers.first?.title, "Test Paper Title")
        XCTAssertEqual(papers.first?.authors, ["Author A", "Author B"])
        XCTAssertEqual(papers.first?.categories, ["cs.AI"])
    }
}
```

**Step 3: Implement ArxivAPIService**

Create `ArxivLearner/Core/Network/ArxivAPIService.swift`:

```swift
import Foundation

struct ArxivSearchParams {
    var query: String
    var category: String?
    var dateRange: DateRange?
    var sortBy: SortField = .relevance
    var start: Int = 0
    var maxResults: Int = 20

    enum DateRange: String {
        case lastWeek, lastMonth, lastThreeMonths, lastYear
    }

    enum SortField: String {
        case relevance
        case lastUpdatedDate
        case submittedDate
    }
}

struct ArxivPaperDTO {
    let arxivId: String
    let title: String
    let authors: [String]
    let abstractText: String
    let categories: [String]
    let publishedDate: Date
    let pdfURL: String
}

final class ArxivAPIService {
    private let baseURL = "https://export.arxiv.org/api/query"
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = .shared) {
        self.httpClient = httpClient
    }

    func search(params: ArxivSearchParams) async throws -> [ArxivPaperDTO] {
        guard let url = buildSearchURL(params: params) else {
            throw HTTPError.invalidURL
        }
        let data = try await httpClient.fetch(url: url)
        return try parseResponse(data: data)
    }

    func buildSearchURL(params: ArxivSearchParams) -> URL? {
        var components = URLComponents(string: baseURL)
        var queryParts: [String] = []

        let escapedQuery = params.query
            .replacingOccurrences(of: " ", with: "+")
        queryParts.append("all:\(escapedQuery)")

        if let cat = params.category {
            queryParts.append("cat:\(cat)")
        }

        let searchQuery = queryParts.joined(separator: "+AND+")

        let sortBy: String
        switch params.sortBy {
        case .relevance: sortBy = "relevance"
        case .lastUpdatedDate: sortBy = "lastUpdatedDate"
        case .submittedDate: sortBy = "submittedDate"
        }

        components?.queryItems = [
            URLQueryItem(name: "search_query", value: searchQuery),
            URLQueryItem(name: "start", value: "\(params.start)"),
            URLQueryItem(name: "max_results", value: "\(params.maxResults)"),
            URLQueryItem(name: "sortBy", value: sortBy),
            URLQueryItem(name: "sortOrder", value: "descending"),
        ]

        return components?.url
    }

    func parseResponse(data: Data) throws -> [ArxivPaperDTO] {
        let parser = ArxivXMLParser(data: data)
        return try parser.parse()
    }
}

// MARK: - XML Parser

final class ArxivXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var papers: [ArxivPaperDTO] = []
    private var currentElement = ""
    private var currentText = ""

    // Current paper being parsed
    private var currentId = ""
    private var currentTitle = ""
    private var currentAbstract = ""
    private var currentAuthors: [String] = []
    private var currentCategories: [String] = []
    private var currentPublished = ""
    private var currentPdfURL = ""
    private var insideEntry = false
    private var insideAuthor = false

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(abbreviation: "UTC")
        return df
    }()

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [ArxivPaperDTO] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return papers
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "entry" {
            insideEntry = true
            currentId = ""
            currentTitle = ""
            currentAbstract = ""
            currentAuthors = []
            currentCategories = []
            currentPublished = ""
            currentPdfURL = ""
        } else if elementName == "author" {
            insideAuthor = true
        } else if elementName == "category", insideEntry {
            if let term = attributes["term"] {
                currentCategories.append(term)
            }
        } else if elementName == "link", insideEntry {
            if attributes["title"] == "pdf",
               let href = attributes["href"] {
                currentPdfURL = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "entry" {
            // Extract arXiv ID from URL like "http://arxiv.org/abs/2401.12345v1"
            let arxivId = currentId
                .replacingOccurrences(of: "http://arxiv.org/abs/", with: "")
                .replacingOccurrences(of: "https://arxiv.org/abs/", with: "")
                .components(separatedBy: "v").first ?? currentId

            let date = dateFormatter.date(from: currentPublished) ?? Date()

            let paper = ArxivPaperDTO(
                arxivId: arxivId,
                title: currentTitle.replacingOccurrences(of: "\n", with: " "),
                authors: currentAuthors,
                abstractText: currentAbstract.replacingOccurrences(of: "\n", with: " "),
                categories: currentCategories,
                publishedDate: date,
                pdfURL: currentPdfURL
            )
            papers.append(paper)
            insideEntry = false
        } else if elementName == "name" && insideAuthor {
            currentAuthors.append(trimmed)
        } else if elementName == "author" {
            insideAuthor = false
        } else if insideEntry {
            switch elementName {
            case "id": currentId = trimmed
            case "title": currentTitle = trimmed
            case "summary": currentAbstract = trimmed
            case "published": currentPublished = trimmed
            default: break
            }
        }
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/ArxivAPIServiceTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS

**Step 5: Commit**

```bash
git add ArxivLearner/Core/Network/ ArxivLearnerTests/Services/ArxivAPIServiceTests.swift
git commit -m "feat: add arXiv API service with XML parsing"
```

---

## Task 6: PDF Download & Cache Manager

**Files:**
- Create: `ArxivLearner/Core/Storage/PDFCacheManager.swift`
- Test: `ArxivLearnerTests/Services/PDFCacheManagerTests.swift`

**Step 1: Write failing tests**

Create `ArxivLearnerTests/Services/PDFCacheManagerTests.swift`:

```swift
import XCTest
@testable import ArxivLearner

final class PDFCacheManagerTests: XCTestCase {
    var cacheManager: PDFCacheManager!

    override func setUp() {
        super.setUp()
        cacheManager = PDFCacheManager(subdirectory: "TestPDFs")
    }

    override func tearDown() {
        super.tearDown()
        cacheManager.clearCache()
    }

    func testCacheDirectory() {
        let dir = cacheManager.cacheDirectory
        XCTAssertTrue(dir.path().contains("TestPDFs"))
    }

    func testLocalPathForPaper() {
        let path = cacheManager.localPath(for: "2401.12345")
        XCTAssertTrue(path.lastPathComponent == "2401.12345.pdf")
    }

    func testIsDownloaded() {
        XCTAssertFalse(cacheManager.isDownloaded(arxivId: "2401.12345"))
    }

    func testCacheSize() {
        let size = cacheManager.totalCacheSize()
        XCTAssertEqual(size, 0)
    }
}
```

**Step 2: Implement PDFCacheManager**

Create `ArxivLearner/Core/Storage/PDFCacheManager.swift`:

```swift
import Foundation

final class PDFCacheManager {
    static let shared = PDFCacheManager()

    let cacheDirectory: URL

    init(subdirectory: String = "PDFs") {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        cacheDirectory = documentsDir.appendingPathComponent(subdirectory)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    func localPath(for arxivId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(arxivId).pdf")
    }

    func isDownloaded(arxivId: String) -> Bool {
        FileManager.default.fileExists(atPath: localPath(for: arxivId).path())
    }

    func download(from urlString: String, arxivId: String,
                  progress: @escaping (Double) -> Void) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw HTTPError.invalidURL
        }

        let destination = localPath(for: arxivId)
        let (tempURL, _) = try await URLSession.shared.download(from: url)

        if FileManager.default.fileExists(atPath: destination.path()) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)

        return destination
    }

    func totalCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    func deletePDF(arxivId: String) {
        let path = localPath(for: arxivId)
        try? FileManager.default.removeItem(at: path)
    }
}
```

**Step 3: Run tests**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/PDFCacheManagerTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS

**Step 4: Commit**

```bash
git add ArxivLearner/Core/Storage/PDFCacheManager.swift ArxivLearnerTests/Services/PDFCacheManagerTests.swift
git commit -m "feat: add PDFCacheManager for download and local storage"
```

---

## Task 7: doc2x Service

**Files:**
- Create: `ArxivLearner/Core/Services/Doc2xService.swift`
- Test: `ArxivLearnerTests/Services/Doc2xServiceTests.swift`

**CRITICAL:** Before writing any code, search the latest doc2x API documentation to confirm:
- Authentication method (API Key header format)
- Upload endpoint and parameters
- Task status polling endpoint
- Result retrieval endpoint
- Rate limits and file size limits

The implementation below is a skeleton. Actual endpoint URLs, request/response formats MUST be verified against the latest docs.

**Step 1: Write test for service structure**

Create `ArxivLearnerTests/Services/Doc2xServiceTests.swift`:

```swift
import XCTest
@testable import ArxivLearner

final class Doc2xServiceTests: XCTestCase {
    func testServiceInitialization() {
        let service = Doc2xService(apiKey: "test-key")
        XCTAssertNotNil(service)
    }

    func testBuildUploadRequest() throws {
        let service = Doc2xService(apiKey: "test-key")
        // Verify request is properly formed (actual URL from latest docs)
        let request = try service.buildUploadRequest(
            pdfData: Data("test".utf8)
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))
    }
}
```

**Step 2: Implement Doc2xService skeleton**

Create `ArxivLearner/Core/Services/Doc2xService.swift`:

```swift
import Foundation

final class Doc2xService {
    // TODO: Verify these URLs against the latest doc2x API documentation
    private var baseURL: String
    private let apiKey: String
    private let httpClient: HTTPClient

    init(apiKey: String,
         baseURL: String = "https://api.doc2x.noedgeai.com",
         httpClient: HTTPClient = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = httpClient
    }

    /// Upload a PDF file and return the task ID
    func uploadPDF(pdfData: Data) async throws -> String {
        let request = try buildUploadRequest(pdfData: pdfData)
        let responseData = try await httpClient.fetch(request: request)
        return try parseUploadResponse(data: responseData)
    }

    /// Poll for conversion status
    func checkStatus(taskId: String) async throws -> Doc2xTaskStatus {
        // TODO: Implement with actual endpoint from latest docs
        let url = URL(string: "\(baseURL)/api/v1/async/status?uuid=\(taskId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let data = try await httpClient.fetch(request: request)
        return try parseStatusResponse(data: data)
    }

    /// Fetch the converted Markdown result
    func fetchResult(taskId: String) async throws -> String {
        // TODO: Implement with actual endpoint from latest docs
        let url = URL(string: "\(baseURL)/api/v1/async/result?uuid=\(taskId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let data = try await httpClient.fetch(request: request)
        return try parseResultResponse(data: data)
    }

    /// Full conversion pipeline: upload → poll → fetch result
    func convert(pdfData: Data, pollInterval: TimeInterval = 3.0,
                 timeout: TimeInterval = 300) async throws -> String {
        let taskId = try await uploadPDF(pdfData: pdfData)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let status = try await checkStatus(taskId: taskId)
            switch status {
            case .completed:
                return try await fetchResult(taskId: taskId)
            case .failed(let message):
                throw Doc2xError.conversionFailed(message)
            case .processing:
                try await Task.sleep(for: .seconds(pollInterval))
            }
        }
        throw Doc2xError.timeout
    }

    // MARK: - Request Building

    func buildUploadRequest(pdfData: Data) throws -> URLRequest {
        // TODO: Verify endpoint and format from latest doc2x docs
        let url = URL(string: "\(baseURL)/api/v1/async/pdf")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"paper.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return request
    }

    // MARK: - Response Parsing (TODO: Update based on actual API response format)

    private func parseUploadResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let uuid = json?["uuid"] as? String else {
            throw Doc2xError.invalidResponse
        }
        return uuid
    }

    private func parseStatusResponse(data: Data) throws -> Doc2xTaskStatus {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = json?["status"] as? String else {
            throw Doc2xError.invalidResponse
        }
        switch status {
        case "success", "completed":
            return .completed
        case "processing", "pending":
            return .processing
        default:
            return .failed(json?["message"] as? String ?? "Unknown error")
        }
    }

    private func parseResultResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let markdown = json?["result"] as? String else {
            throw Doc2xError.invalidResponse
        }
        return markdown
    }
}

enum Doc2xTaskStatus {
    case processing
    case completed
    case failed(String)
}

enum Doc2xError: Error {
    case invalidResponse
    case conversionFailed(String)
    case timeout
}
```

**Step 3: Run tests**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/Doc2xServiceTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: PASS

**Step 4: Commit**

```bash
git add ArxivLearner/Core/Services/ ArxivLearnerTests/Services/Doc2xServiceTests.swift
git commit -m "feat: add doc2x service skeleton for PDF-to-Markdown conversion"
```

---

## Task 8: LLM Service Layer

**Files:**
- Create: `ArxivLearner/Core/LLM/LLMServiceProtocol.swift`
- Create: `ArxivLearner/Core/LLM/OpenAICompatibleService.swift`
- Create: `ArxivLearner/Core/LLM/ContextBuilder.swift`
- Test: `ArxivLearnerTests/Services/LLMServiceTests.swift`

**IMPORTANT:** Search latest OpenAI Chat Completions API docs before implementing to confirm streaming format (SSE), request/response schema, and model IDs.

**Step 1: Write tests**

Create `ArxivLearnerTests/Services/LLMServiceTests.swift`:

```swift
import XCTest
@testable import ArxivLearner

final class LLMServiceTests: XCTestCase {
    func testBuildChatRequest() throws {
        let config = LLMProviderConfig(
            name: "Test",
            baseURL: "https://api.openai.com/v1",
            apiKey: "sk-test",
            modelId: "gpt-4o"
        )
        let service = OpenAICompatibleService(config: config)
        let messages: [LLMMessage] = [
            LLMMessage(role: "system", content: "You are helpful."),
            LLMMessage(role: "user", content: "Hello"),
        ]
        let request = try service.buildRequest(messages: messages, stream: false)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
    }

    func testContextBuilderPrefersMarkdown() {
        let paper = ContextBuilder.PaperContext(
            title: "Test",
            abstractText: "Abstract text",
            markdownContent: "# Full Markdown Content",
            fullText: nil
        )
        let context = ContextBuilder.buildContext(for: paper)
        XCTAssertTrue(context.contains("# Full Markdown Content"))
    }

    func testContextBuilderFallsBackToAbstract() {
        let paper = ContextBuilder.PaperContext(
            title: "Test",
            abstractText: "Abstract text only",
            markdownContent: nil,
            fullText: nil
        )
        let context = ContextBuilder.buildContext(for: paper)
        XCTAssertTrue(context.contains("Abstract text only"))
    }
}
```

**Step 2: Implement LLM protocol and types**

Create `ArxivLearner/Core/LLM/LLMServiceProtocol.swift`:

```swift
import Foundation

struct LLMMessage: Codable {
    let role: String
    let content: String
}

protocol LLMServiceProtocol {
    func complete(messages: [LLMMessage], stream: Bool) async throws -> String
    func completeStream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error>
}
```

**Step 3: Implement OpenAI compatible service**

Create `ArxivLearner/Core/LLM/OpenAICompatibleService.swift`:

```swift
import Foundation

final class OpenAICompatibleService: LLMServiceProtocol {
    private let config: LLMProviderConfig

    init(config: LLMProviderConfig) {
        self.config = config
    }

    func complete(messages: [LLMMessage], stream: Bool) async throws -> String {
        let request = try buildRequest(messages: messages, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.badResponse
        }
        return try parseResponse(data: data)
    }

    func completeStream(messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(messages: messages, stream: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: LLMError.badResponse)
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if jsonStr == "[DONE]" { break }
                            if let data = jsonStr.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        let endpoint = config.baseURL.hasSuffix("/")
            ? "\(config.baseURL)chat/completions"
            : "\(config.baseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.modelId,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": stream,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }
}

enum LLMError: Error {
    case badResponse
    case invalidURL
    case invalidResponse
}
```

**Step 4: Implement ContextBuilder**

Create `ArxivLearner/Core/LLM/ContextBuilder.swift`:

```swift
import Foundation

enum ContextBuilder {
    struct PaperContext {
        let title: String
        let abstractText: String
        let markdownContent: String?
        let fullText: String?
    }

    /// Build the best available context for LLM.
    /// Priority: Markdown (doc2x) > full text > abstract only
    static func buildContext(for paper: PaperContext) -> String {
        if let markdown = paper.markdownContent, !markdown.isEmpty {
            return """
            论文标题: \(paper.title)

            以下是论文全文(Markdown格式):

            \(markdown)
            """
        }

        if let fullText = paper.fullText, !fullText.isEmpty {
            return """
            论文标题: \(paper.title)

            以下是论文全文:

            \(fullText)
            """
        }

        return """
        论文标题: \(paper.title)

        摘要:
        \(paper.abstractText)
        """
    }

    /// Build system prompt for insight generation
    static func insightSystemPrompt() -> String {
        """
        你是一位资深学术研究者。请根据提供的论文内容，生成简洁的核心见解，包括：
        1. 🎯 核心贡献（1-2句话）
        2. 📊 主要结果（关键数据和结论）
        请用中文回答，保持简洁。
        """
    }
}
```

**Step 5: Run tests**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/LLMServiceTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: All tests PASS

**Step 6: Commit**

```bash
git add ArxivLearner/Core/LLM/ ArxivLearnerTests/Services/LLMServiceTests.swift
git commit -m "feat: add LLM service protocol, OpenAI-compatible impl, and ContextBuilder"
```

---

## Task 9: Search Feature (View + ViewModel)

**Files:**
- Create: `ArxivLearner/Features/Search/SearchViewModel.swift`
- Create: `ArxivLearner/Features/Search/SearchView.swift`
- Test: `ArxivLearnerTests/ViewModels/SearchViewModelTests.swift`

**Step 1: Write ViewModel tests**

Create `ArxivLearnerTests/ViewModels/SearchViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import ArxivLearner

final class SearchViewModelTests: XCTestCase {
    func testInitialState() {
        let vm = SearchViewModel()
        XCTAssertTrue(vm.papers.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(vm.query, "")
    }

    func testSearchQueryNotEmpty() {
        let vm = SearchViewModel()
        vm.query = "  "
        // Should not search with whitespace-only query
        XCTAssertTrue(vm.query.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
```

**Step 2: Implement SearchViewModel**

Create `ArxivLearner/Features/Search/SearchViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
final class SearchViewModel {
    var query = ""
    var selectedCategory: String?
    var selectedDateRange: ArxivSearchParams.DateRange?
    var selectedSortBy: ArxivSearchParams.SortField = .relevance
    var papers: [ArxivPaperDTO] = []
    var isLoading = false
    var errorMessage: String?
    var hasMoreResults = true

    private let arxivService = ArxivAPIService()
    private var currentPage = 0
    private let pageSize = 20

    var availableCategories: [String] {
        ["cs.AI", "cs.LG", "cs.CV", "cs.CL", "cs.RO", "cs.NE", "stat.ML"]
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 0
        papers = []

        do {
            let params = ArxivSearchParams(
                query: trimmed,
                category: selectedCategory,
                dateRange: selectedDateRange,
                sortBy: selectedSortBy,
                start: 0,
                maxResults: pageSize
            )
            let results = try await arxivService.search(params: params)
            papers = results
            hasMoreResults = results.count == pageSize
        } catch {
            errorMessage = "搜索失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMoreResults, !isLoading else { return }
        isLoading = true
        currentPage += 1

        do {
            let params = ArxivSearchParams(
                query: query.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                dateRange: selectedDateRange,
                sortBy: selectedSortBy,
                start: currentPage * pageSize,
                maxResults: pageSize
            )
            let results = try await arxivService.search(params: params)
            papers.append(contentsOf: results)
            hasMoreResults = results.count == pageSize
        } catch {
            errorMessage = "加载更多失败: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
```

**Step 3: Implement SearchView**

Create `ArxivLearner/Features/Search/SearchView.swift`:

```swift
import SwiftUI
import SwiftData

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showFilters = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if showFilters { filterBar }
                resultsList
            }
            .navigationTitle("发现")
        }
    }

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("搜索 arXiv...", text: $viewModel.query)
                    .onSubmit { Task { await viewModel.search() } }
                if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button { showFilters.toggle() } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(
                        showFilters ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                    )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category picker
                Menu {
                    Button("全部分类") { viewModel.selectedCategory = nil }
                    ForEach(viewModel.availableCategories, id: \.self) { cat in
                        Button(cat) { viewModel.selectedCategory = cat }
                    }
                } label: {
                    TagChip(
                        text: viewModel.selectedCategory ?? "分类",
                        color: viewModel.selectedCategory != nil
                            ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
                    )
                }

                // Sort picker
                Menu {
                    Button("相关度") { viewModel.selectedSortBy = .relevance }
                    Button("最新发布") { viewModel.selectedSortBy = .submittedDate }
                    Button("最近更新") { viewModel.selectedSortBy = .lastUpdatedDate }
                } label: {
                    TagChip(text: sortLabel, color: AppTheme.Colors.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var sortLabel: String {
        switch viewModel.selectedSortBy {
        case .relevance: "相关度"
        case .submittedDate: "最新发布"
        case .lastUpdatedDate: "最近更新"
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Dimensions.spacing) {
                ForEach(Array(viewModel.papers.enumerated()), id: \.element.arxivId) { index, paper in
                    CompactCardView(paper: paper, modelContext: modelContext)
                        .onAppear {
                            if index == viewModel.papers.count - 3 {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: Paper.self, inMemory: true)
}
```

**Step 4: Run tests and verify build**

```bash
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivLearnerTests/SearchViewModelTests 2>&1 | grep -E "(Test|PASS|FAIL)"
```

Expected: PASS

**Step 5: Commit**

```bash
git add ArxivLearner/Features/Search/ ArxivLearnerTests/ViewModels/
git commit -m "feat: add Search feature with ViewModel, View, and filters"
```

---

## Task 10: PDF Reader View

**Files:**
- Create: `ArxivLearner/Features/Reader/PDFReaderView.swift`
- Create: `ArxivLearner/Features/Reader/PDFReaderViewModel.swift`

**Step 1: Implement PDFReaderViewModel**

Create `ArxivLearner/Features/Reader/PDFReaderViewModel.swift`:

```swift
import Foundation
import PDFKit
import Observation

@Observable
final class PDFReaderViewModel {
    var pdfDocument: PDFDocument?
    var currentPage: Int = 0
    var totalPages: Int = 0
    var isLoading = false
    var errorMessage: String?

    func loadPDF(from url: URL) {
        isLoading = true
        if let doc = PDFDocument(url: url) {
            pdfDocument = doc
            totalPages = doc.pageCount
        } else {
            errorMessage = "无法加载 PDF 文件"
        }
        isLoading = false
    }

    func loadPDF(from data: Data) {
        isLoading = true
        if let doc = PDFDocument(data: data) {
            pdfDocument = doc
            totalPages = doc.pageCount
        } else {
            errorMessage = "无法解析 PDF 数据"
        }
        isLoading = false
    }
}
```

**Step 2: Implement PDFReaderView**

Create `ArxivLearner/Features/Reader/PDFReaderView.swift`:

```swift
import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let title: String
    let pdfURL: URL
    @State private var viewModel = PDFReaderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else if let doc = viewModel.pdfDocument {
                    PDFKitView(document: doc)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.totalPages > 0 {
                        Text("共 \(viewModel.totalPages) 页")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear { viewModel.loadPDF(from: pdfURL) }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
```

**Step 3: Verify build**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ArxivLearner/Features/Reader/
git commit -m "feat: add PDF reader with PDFKit integration"
```

---

## Task 11: LLM Insight Generation

**Files:**
- Create: `ArxivLearner/Features/Cards/InsightViewModel.swift`

**Step 1: Implement InsightViewModel**

Create `ArxivLearner/Features/Cards/InsightViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class InsightViewModel {
    var insight: String = ""
    var isGenerating = false
    var errorMessage: String?

    private var llmService: LLMServiceProtocol?

    func configure(config: LLMProviderConfig) {
        self.llmService = OpenAICompatibleService(config: config)
    }

    func generateInsight(for paper: Paper) async {
        guard let service = llmService else {
            errorMessage = "请先配置 LLM 服务"
            return
        }

        isGenerating = true
        errorMessage = nil
        insight = ""

        let paperContext = ContextBuilder.PaperContext(
            title: paper.title,
            abstractText: paper.abstractText,
            markdownContent: paper.markdownContent,
            fullText: nil
        )

        let messages: [LLMMessage] = [
            LLMMessage(role: "system", content: ContextBuilder.insightSystemPrompt()),
            LLMMessage(role: "user", content: ContextBuilder.buildContext(for: paperContext)),
        ]

        do {
            for try await chunk in service.completeStream(messages: messages) {
                insight += chunk
            }
            // Save to paper
            paper.llmInsight = insight
        } catch {
            errorMessage = "生成失败: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func regenerate(for paper: Paper) async {
        insight = ""
        paper.llmInsight = nil
        await generateInsight(for: paper)
    }
}
```

**Step 2: Verify build and commit**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

```bash
git add ArxivLearner/Features/Cards/InsightViewModel.swift
git commit -m "feat: add InsightViewModel with streaming LLM insight generation"
```

---

## Task 12: Compact Card View

**Files:**
- Create: `ArxivLearner/Features/Cards/CompactCardView.swift`

**Step 1: Implement CompactCardView**

Create `ArxivLearner/Features/Cards/CompactCardView.swift`:

```swift
import SwiftUI
import SwiftData

struct CompactCardView: View {
    let paper: ArxivPaperDTO
    let modelContext: ModelContext
    @State private var isFavorite = false
    @State private var showFullCard = false

    var body: some View {
        Button { showFullCard = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Top row: categories + status + favorite
                HStack {
                    ForEach(paper.categories.prefix(2), id: \.self) { cat in
                        TagChip(
                            text: cat,
                            color: AppTheme.Colors.categoryColor(for: cat)
                        )
                    }
                    Spacer()
                    Button {
                        isFavorite.toggle()
                        saveFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : AppTheme.Colors.textSecondary)
                    }
                }

                // Title
                Text(paper.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                // Author + date
                HStack {
                    Text(authorSummary)
                    Text("·")
                    Text(paper.publishedDate, format: .dateTime.year().month())
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

                // Abstract
                Text(paper.abstractText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(AppTheme.Dimensions.cardPadding)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
            .shadow(
                color: .black.opacity(0.1),
                radius: AppTheme.Dimensions.cardShadowRadius,
                x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullCard) {
            FullCardView(paper: paper, modelContext: modelContext)
        }
    }

    private var authorSummary: String {
        if paper.authors.count <= 2 {
            return paper.authors.joined(separator: ", ")
        }
        return "\(paper.authors[0]) et al."
    }

    private func saveFavorite() {
        // Check if paper already exists in SwiftData
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite = isFavorite
        } else if isFavorite {
            let newPaper = Paper(
                arxivId: paper.arxivId,
                title: paper.title,
                authors: paper.authors,
                abstractText: paper.abstractText,
                categories: paper.categories,
                publishedDate: paper.publishedDate,
                pdfURL: paper.pdfURL,
                isFavorite: true
            )
            modelContext.insert(newPaper)
        }
        try? modelContext.save()
    }
}
```

**Step 2: Verify build and commit**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

```bash
git add ArxivLearner/Features/Cards/CompactCardView.swift
git commit -m "feat: add CompactCardView for search results"
```

---

## Task 13: Full Card View with 3D Flip Animation

**Files:**
- Create: `ArxivLearner/Features/Cards/FullCardView.swift`
- Create: `ArxivLearner/Features/Cards/CardFlipModifier.swift`

**Step 1: Create CardFlipModifier**

Create `ArxivLearner/Features/Cards/CardFlipModifier.swift`:

```swift
import SwiftUI

struct CardFlipModifier: AnimatableModifier {
    var rotation: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .opacity(rotation > 90 && rotation < 270 ? 0 : 1)
    }
}

extension View {
    func cardFlip(isFlipped: Bool) -> some View {
        modifier(CardFlipModifier(rotation: isFlipped ? 180 : 0))
    }
}
```

**Step 2: Implement FullCardView**

Create `ArxivLearner/Features/Cards/FullCardView.swift`:

```swift
import SwiftUI
import SwiftData

struct FullCardView: View {
    let paper: ArxivPaperDTO
    let modelContext: ModelContext
    @State private var isFlipped = false
    @State private var insightVM = InsightViewModel()
    @State private var showPDFReader = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Front
                cardFront
                    .cardFlip(isFlipped: false)
                    .opacity(isFlipped ? 0 : 1)

                // Back
                cardBack
                    .cardFlip(isFlipped: true)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .animation(.spring(duration: 0.6), value: isFlipped)
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Front

    private var cardFront: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Categories + favorite
            HStack {
                ForEach(paper.categories, id: \.self) { cat in
                    TagChip(text: cat, color: AppTheme.Colors.categoryColor(for: cat))
                }
                Spacer()
                Image(systemName: "heart")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Image(systemName: "ellipsis")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Title
            Text(paper.title)
                .font(.title3)
                .fontWeight(.bold)

            // Authors
            Text(paper.authors.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // Abstract
            ScrollView {
                Text(paper.abstractText)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                actionButton(icon: "doc.fill", label: "PDF") {
                    Task { await downloadAndOpenPDF() }
                }
                actionButton(icon: "doc.text.fill", label: "转MD") {
                    // doc2x conversion - to be wired
                }
                actionButton(icon: "lightbulb.fill", label: "见解") {
                    isFlipped = true
                    Task { await generateInsightIfNeeded() }
                }
                actionButton(icon: "bubble.left.fill", label: "问答") {
                    // Chat - MVP placeholder
                }
            }

            // Date + flip hint
            HStack {
                Text(paper.publishedDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                Button { withAnimation { isFlipped.toggle() } } label: {
                    Label("点击翻转", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .padding(AppTheme.Dimensions.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    // MARK: - Back

    private var cardBack: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("核心见解", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.primary)
                Spacer()
                Button { withAnimation { isFlipped.toggle() } } label: {
                    Label("翻转", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            Divider()

            // Insight content
            ScrollView {
                if insightVM.isGenerating {
                    VStack {
                        ProgressView()
                        Text("正在生成见解...")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                if !insightVM.insight.isEmpty {
                    Text(insightVM.insight)
                        .font(.body)
                } else if !insightVM.isGenerating {
                    Text(paper.abstractText)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .italic()
                }

                if let error = insightVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Back action buttons (6 buttons in 3 rows)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    actionButton(icon: "lightbulb.fill", label: "创新点") {}
                    actionButton(icon: "function", label: "公式解析") {}
                }
                HStack(spacing: 8) {
                    actionButton(icon: "bubble.left.fill", label: "论文问答") {}
                    actionButton(icon: "globe", label: "全文翻译") {}
                }
                HStack(spacing: 8) {
                    actionButton(icon: "book.fill", label: "展开全文") {
                        Task { await downloadAndOpenPDF() }
                    }
                    actionButton(icon: "arrow.clockwise", label: "重新生成") {
                        Task { await insightVM.regenerate(for: getOrCreatePaper()) }
                    }
                }
            }
        }
        .padding(AppTheme.Dimensions.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .sheet(isPresented: $showPDFReader) {
            if let localPath = PDFCacheManager.shared.localPath(for: paper.arxivId) as URL? ,
               PDFCacheManager.shared.isDownloaded(arxivId: paper.arxivId) {
                PDFReaderView(title: paper.title, pdfURL: localPath)
            }
        }
    }

    // MARK: - Helpers

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.buttonCornerRadius))
        }
        .foregroundStyle(AppTheme.Colors.primary)
    }

    private func downloadAndOpenPDF() async {
        guard !PDFCacheManager.shared.isDownloaded(arxivId: paper.arxivId) else {
            showPDFReader = true
            return
        }
        isDownloading = true
        do {
            _ = try await PDFCacheManager.shared.download(
                from: paper.pdfURL,
                arxivId: paper.arxivId,
                progress: { downloadProgress = $0 }
            )
            let savedPaper = getOrCreatePaper()
            savedPaper.isDownloaded = true
            savedPaper.pdfLocalPath = PDFCacheManager.shared.localPath(for: paper.arxivId).path()
            try? modelContext.save()
            showPDFReader = true
        } catch {
            // Handle error
        }
        isDownloading = false
    }

    private func generateInsightIfNeeded() async {
        let savedPaper = getOrCreatePaper()
        if let existing = savedPaper.llmInsight, !existing.isEmpty {
            insightVM.insight = existing
            return
        }
        // Load LLM config from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "llm_config"),
           let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: data) {
            insightVM.configure(config: config)
            await insightVM.generateInsight(for: savedPaper)
        } else {
            insightVM.errorMessage = "请先在设置中配置 LLM 服务"
        }
    }

    private func getOrCreatePaper() -> Paper {
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let newPaper = Paper(
            arxivId: paper.arxivId,
            title: paper.title,
            authors: paper.authors,
            abstractText: paper.abstractText,
            categories: paper.categories,
            publishedDate: paper.publishedDate,
            pdfURL: paper.pdfURL
        )
        modelContext.insert(newPaper)
        try? modelContext.save()
        return newPaper
    }
}
```

**Step 3: Verify build and commit**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

```bash
git add ArxivLearner/Features/Cards/
git commit -m "feat: add FullCardView with 3D flip animation and card back with 6 action buttons"
```

---

## Task 14: Library Feature

**Files:**
- Create: `ArxivLearner/Features/Library/LibraryView.swift`
- Create: `ArxivLearner/Features/Library/LibraryViewModel.swift`

**Step 1: Implement LibraryViewModel**

Create `ArxivLearner/Features/Library/LibraryViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
final class LibraryViewModel {
    enum Filter: String, CaseIterable {
        case favorites = "收藏"
        case downloaded = "已下载"
        case all = "全部"
    }

    var selectedFilter: Filter = .favorites
}
```

**Step 2: Implement LibraryView**

Create `ArxivLearner/Features/Library/LibraryView.swift`:

```swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @Query private var allPapers: [Paper]
    @Environment(\.modelContext) private var modelContext

    var filteredPapers: [Paper] {
        switch viewModel.selectedFilter {
        case .favorites:
            return allPapers.filter { $0.isFavorite }
        case .downloaded:
            return allPapers.filter { $0.isDownloaded }
        case .all:
            return allPapers
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                Picker("筛选", selection: $viewModel.selectedFilter) {
                    ForEach(LibraryViewModel.Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Paper list
                if filteredPapers.isEmpty {
                    ContentUnavailableView(
                        "暂无论文",
                        systemImage: "book.closed",
                        description: Text("搜索并收藏论文后会在这里显示")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Dimensions.spacing) {
                            ForEach(filteredPapers, id: \.arxivId) { paper in
                                LibraryCardView(paper: paper)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("文库")
        }
    }
}

struct LibraryCardView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ForEach(paper.categories.prefix(2), id: \.self) { cat in
                    TagChip(text: cat, color: AppTheme.Colors.categoryColor(for: cat))
                }

                Spacer()

                if paper.markdownConvertStatus == .completed {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondary)
                }

                if paper.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Image(systemName: paper.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(paper.isFavorite ? .red : AppTheme.Colors.textSecondary)
            }

            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            HStack {
                Text(paper.authors.first ?? "")
                if paper.authors.count > 1 { Text("et al.") }
                Text("·")
                Text(paper.publishedDate, format: .dateTime.year().month())
            }
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.textSecondary)

            Text(paper.abstractText)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(AppTheme.Dimensions.cardPadding)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Dimensions.cardCornerRadius))
        .shadow(color: .black.opacity(0.1), radius: AppTheme.Dimensions.cardShadowRadius, x: 0, y: 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Paper.self, inMemory: true)
}
```

**Step 3: Verify build and commit**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

```bash
git add ArxivLearner/Features/Library/
git commit -m "feat: add Library feature with favorites/downloaded filtering"
```

---

## Task 15: Settings View

**Files:**
- Create: `ArxivLearner/Features/Settings/SettingsView.swift`

**Step 1: Implement SettingsView (MVP: LLM config + doc2x config)**

Create `ArxivLearner/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    // LLM
    @AppStorage("llm_name") private var llmName = "OpenAI"
    @AppStorage("llm_base_url") private var llmBaseURL = "https://api.openai.com/v1"
    @AppStorage("llm_model_id") private var llmModelId = "gpt-4o"
    @State private var llmApiKey = ""

    // doc2x
    @AppStorage("doc2x_base_url") private var doc2xBaseURL = "https://api.doc2x.noedgeai.com"
    @State private var doc2xApiKey = ""

    // Cache
    @State private var cacheSize: String = "计算中..."
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // LLM Section
                Section("LLM 服务") {
                    TextField("服务商名称", text: $llmName)
                    TextField("Base URL", text: $llmBaseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    SecureField("API Key", text: $llmApiKey)
                    TextField("Model ID", text: $llmModelId)
                        .autocapitalization(.none)
                    Button("保存并测试") { saveLLMConfig() }
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                // doc2x Section
                Section("文档转换 (doc2x)") {
                    TextField("服务端点", text: $doc2xBaseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    SecureField("API Key", text: $doc2xApiKey)
                    Button("保存") { saveDoc2xConfig() }
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                // Cache Section
                Section("存储") {
                    HStack {
                        Text("PDF 缓存")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Button("清除缓存", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                // About
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { loadKeys(); calculateCacheSize() }
            .alert("确认清除", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) {
                    PDFCacheManager.shared.clearCache()
                    calculateCacheSize()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除所有已下载的 PDF 文件")
            }
        }
    }

    private func loadKeys() {
        llmApiKey = (try? KeychainService.shared.retrieve(key: "llm_api_key")) ?? ""
        doc2xApiKey = (try? KeychainService.shared.retrieve(key: "doc2x_api_key")) ?? ""
    }

    private func saveLLMConfig() {
        try? KeychainService.shared.save(key: "llm_api_key", value: llmApiKey)
        let config = LLMProviderConfig(
            name: llmName,
            baseURL: llmBaseURL,
            apiKey: llmApiKey,
            modelId: llmModelId
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "llm_config")
        }
    }

    private func saveDoc2xConfig() {
        try? KeychainService.shared.save(key: "doc2x_api_key", value: doc2xApiKey)
        UserDefaults.standard.set(doc2xBaseURL, forKey: "doc2x_base_url")
    }

    private func calculateCacheSize() {
        let bytes = PDFCacheManager.shared.totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    SettingsView()
}
```

**Step 2: Verify build and commit**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

```bash
git add ArxivLearner/Features/Settings/
git commit -m "feat: add Settings view with LLM and doc2x configuration"
```

---

## Task 16: App Shell — Tab Navigation

**Files:**
- Modify: `ArxivLearner/App/ContentView.swift`
- Modify: `ArxivLearner/App/ArxivLearnerApp.swift`

**Step 1: Update ContentView with Tab navigation**

Replace `ArxivLearner/App/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("发现", systemImage: "magnifyingglass")
                }
                .tag(0)

            LibraryView()
                .tabItem {
                    Label("文库", systemImage: "books.vertical")
                }
                .tag(1)

            // Chat placeholder for MVP
            NavigationStack {
                ContentUnavailableView(
                    "即将推出",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("论文对话功能将在下一版本推出")
                )
                .navigationTitle("对话")
            }
            .tabItem {
                Label("对话", systemImage: "bubble.left")
            }
            .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(AppTheme.Colors.primary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Paper.self, ChatMessage.self], inMemory: true)
}
```

**Step 2: Update App entry point**

Replace `ArxivLearner/App/ArxivLearnerApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ArxivLearnerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Paper.self, ChatMessage.self])
    }
}
```

**Step 3: Final full build and test**

```bash
xcodebuild -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
xcodebuild test -project ArxivLearner.xcodeproj -scheme ArxivLearner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test Suite|Executed|FAIL)"
```

Expected: BUILD SUCCEEDED, all tests pass

**Step 4: Commit**

```bash
git add ArxivLearner/App/
git commit -m "feat: add Tab navigation shell connecting all MVP features"
```

---

## Execution Summary

| Task | Agent | Description | Depends On |
|------|-------|-------------|------------|
| 1 | A | Project scaffolding + XcodeGen | — |
| 2 | A | SwiftData models | 1 |
| 3 | A | Theme + shared components | 1 |
| 4 | A | Keychain service | 1 |
| 5 | B | arXiv API service | 2 |
| 6 | C | PDF cache manager | 2 |
| 7 | C | doc2x service | 2 |
| 8 | D | LLM service + ContextBuilder | 2, 4 |
| 9 | B | Search feature (View + VM) | 5, 12 |
| 10 | C | PDF reader | 6 |
| 11 | D | Insight generation VM | 8 |
| 12 | E | Compact card view | 2, 3 |
| 13 | E | Full card view + flip | 2, 3, 11 |
| 14 | F | Library feature | 2 |
| 15 | F | Settings view | 4, 7 |
| 16 | F | App shell (tabs) | 9, 14, 15 |

**Total: 16 tasks, 6 parallel agents, ~45 commits**

After Task 16 completion, run full integration test on iOS Simulator to verify the complete flow: Search → Card → Flip → PDF → Insight.
