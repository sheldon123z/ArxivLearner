import Foundation
import SwiftData

// MARK: - ConvertStatus

enum ConvertStatus: String, Codable {
    case none
    case converting
    case completed
    case failed
}

// MARK: - Paper

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
    var markdownConvertStatus: String
    var markdownConvertedAt: Date?
    var createdAt: Date

    // Computed helper for typed access to the convert status
    var convertStatus: ConvertStatus {
        get { ConvertStatus(rawValue: markdownConvertStatus) ?? .none }
        set { markdownConvertStatus = newValue.rawValue }
    }

    // Phase 3: browsing state
    var viewedAt: Date?
    var iCloudSyncEnabled: Bool

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.paper)
    var chatMessages: [ChatMessage] = []

    @Relationship
    var tagItems: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \Annotation.paper)
    var annotations: [Annotation] = []

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.paper)
    var readingSessions: [ReadingSession] = []

    /// Convert to ArxivPaperDTO for views that expect the DTO type.
    var toDTO: ArxivPaperDTO {
        ArxivPaperDTO(
            arxivId: arxivId,
            title: title,
            authors: authors,
            abstractText: abstractText,
            categories: categories,
            publishedDate: publishedDate,
            pdfURL: URL(string: pdfURL) ?? URL(string: "https://arxiv.org/pdf/\(arxivId)")!
        )
    }

    init(
        arxivId: String,
        title: String = "",
        authors: [String] = [],
        abstractText: String = "",
        categories: [String] = [],
        publishedDate: Date = .now,
        pdfURL: String = "",
        pdfLocalPath: String? = nil,
        isDownloaded: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = [],
        llmInsight: String? = nil,
        markdownContent: String? = nil,
        markdownConvertStatus: ConvertStatus = .none,
        markdownConvertedAt: Date? = nil,
        createdAt: Date = .now,
        viewedAt: Date? = nil,
        iCloudSyncEnabled: Bool = false
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
        self.markdownConvertStatus = markdownConvertStatus.rawValue
        self.markdownConvertedAt = markdownConvertedAt
        self.createdAt = createdAt
        self.viewedAt = viewedAt
        self.iCloudSyncEnabled = iCloudSyncEnabled
    }
}
