import Foundation

// MARK: - PDFDownloadError

enum PDFDownloadError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(statusCode: Int)
    case fileMoveError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided URL string is invalid."
        case .downloadFailed(let statusCode):
            return "PDF download failed with HTTP status code: \(statusCode)."
        case .fileMoveError(let error):
            return "Failed to move downloaded file to cache: \(error.localizedDescription)"
        }
    }
}

// MARK: - PDFCacheManager

/// Manages downloading and on-disk caching of PDF files keyed by arXiv ID.
final class PDFCacheManager {

    // MARK: Singleton

    static let shared = PDFCacheManager()

    // MARK: Properties

    /// The directory where cached PDF files are stored.
    let cacheDirectory: URL

    // MARK: Init

    /// Creates a cache manager that stores files under Documents/<subdirectory>.
    /// - Parameter subdirectory: Name of the subdirectory inside the Documents folder.
    init(subdirectory: String = "PDFs") {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        cacheDirectory = documents.appendingPathComponent(subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: Public API

    /// Returns the local file URL for the PDF associated with the given arXiv ID.
    /// - Parameter arxivId: The arXiv paper identifier, e.g. "2401.12345".
    /// - Returns: A URL of the form `<cacheDirectory>/2401.12345.pdf`.
    func localPath(for arxivId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(arxivId).pdf")
    }

    /// Indicates whether a PDF for the given arXiv ID has already been cached locally.
    /// - Parameter arxivId: The arXiv paper identifier.
    func isDownloaded(arxivId: String) -> Bool {
        FileManager.default.fileExists(atPath: localPath(for: arxivId).path)
    }

    /// Downloads a PDF from the given URL and saves it to the local cache.
    ///
    /// - Parameters:
    ///   - urlString: The remote URL of the PDF.
    ///   - arxivId: The arXiv paper identifier used as the local filename.
    ///   - progress: A closure called on the main queue with a value in `0.0...1.0` as the download proceeds.
    /// - Returns: The local URL where the PDF was saved.
    /// - Throws: `PDFDownloadError` on failure.
    @discardableResult
    func download(
        from urlString: String,
        arxivId: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw PDFDownloadError.invalidURL
        }

        let destination = localPath(for: arxivId)

        // If already cached, report complete and return immediately.
        if FileManager.default.fileExists(atPath: destination.path) {
            await MainActor.run { progress(1.0) }
            return destination
        }

        let delegate = DownloadProgressDelegate(progressHandler: { fraction in
            Task { @MainActor in progress(fraction) }
        })

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )

        let (tempURL, response) = try await session.download(from: url)
        session.invalidateAndCancel()

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw PDFDownloadError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        do {
            // Remove stale file if one somehow exists before moving.
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
        } catch {
            throw PDFDownloadError.fileMoveError(underlying: error)
        }

        await MainActor.run { progress(1.0) }
        return destination
    }

    /// Returns the total size of all cached PDF files in bytes.
    func totalCacheSize() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }

        return contents.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
    }

    /// Removes every PDF file from the cache directory.
    func clearCache() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Removes the cached PDF for the given arXiv ID, if it exists.
    /// - Parameter arxivId: The arXiv paper identifier.
    func deletePDF(arxivId: String) {
        let path = localPath(for: arxivId)
        try? FileManager.default.removeItem(at: path)
    }
}

// MARK: - DownloadProgressDelegate

/// A URLSession delegate that forwards download progress to a closure.
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {

    private let progressHandler: (Double) -> Void

    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled by the async/await continuation in PDFCacheManager.download.
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(min(max(fraction, 0.0), 1.0))
    }
}
