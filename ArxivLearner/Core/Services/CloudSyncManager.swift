import Foundation
import SwiftData

// MARK: - CloudSyncManager
//
// Manages iCloud Drive PDF sync for papers with iCloudSyncEnabled == true.
// Uses FileManager ubiquity container for file-level iCloud sync.

@MainActor
final class CloudSyncManager {

    // MARK: Singleton

    static let shared = CloudSyncManager()

    // MARK: Private

    private let ubiquityContainerID = "iCloud.com.arxivlearner.app"

    private var ubiquityURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: ubiquityContainerID)
    }

    private var pdfsURL: URL? {
        ubiquityURL?.appendingPathComponent("Documents/PDFs", isDirectory: true)
    }

    private init() {}

    // MARK: - Upload PDF

    /// Uploads the local PDF for a paper to iCloud Drive if sync is enabled.
    func uploadPDF(for paper: Paper) async throws {
        guard paper.iCloudSyncEnabled else { return }
        guard let localPath = paper.pdfLocalPath else { return }
        guard let targetDir = pdfsURL else { return }

        let localURL = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: localURL.path) else { return }

        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let targetURL = targetDir.appendingPathComponent("\(paper.arxivId).pdf")

        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: localURL, to: targetURL)
    }

    // MARK: - Download PDF

    /// Downloads a PDF from iCloud Drive to local cache for a paper.
    func downloadPDF(for paper: Paper) async throws -> URL? {
        guard paper.iCloudSyncEnabled else { return nil }
        guard let sourceDir = pdfsURL else { return nil }

        let sourceURL = sourceDir.appendingPathComponent("\(paper.arxivId).pdf")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        // Start download if needed (file may exist as placeholder)
        try FileManager.default.startDownloadingUbiquitousItem(at: sourceURL)

        let localURL = PDFCacheManager.shared.localPath(for: paper.arxivId)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(paper.arxivId).pdf")

        try FileManager.default.copyItem(at: sourceURL, to: localURL)
        return localURL
    }

    // MARK: - isFavorite Union Merge Strategy (Task 1.4)

    /// Resolves isFavorite conflicts using union strategy:
    /// if either copy has isFavorite = true, the result is true.
    func mergedIsFavorite(local: Bool, remote: Bool) -> Bool {
        return local || remote
    }

    /// Applies union merge policy across a list of papers.
    /// Pass remote isFavorite values keyed by arxivId.
    func applyFavoriteMerge(papers: [Paper], remoteValues: [String: Bool]) {
        for paper in papers {
            if let remoteValue = remoteValues[paper.arxivId] {
                paper.isFavorite = mergedIsFavorite(local: paper.isFavorite, remote: remoteValue)
            }
        }
    }

    // MARK: - Sync Status

    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
