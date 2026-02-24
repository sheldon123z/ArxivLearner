import Foundation
import SwiftData

// MARK: - AutoConvertMode

/// Controls when doc2x PDF-to-Markdown conversion is triggered.
enum AutoConvertMode: String, CaseIterable {
    /// Convert automatically as soon as a PDF download completes.
    case afterDownload
    /// Show a prompt asking the user before converting.
    case manualOnly
    /// Never convert automatically; user must request conversion explicitly.
    case disabled

    var displayName: String {
        switch self {
        case .afterDownload: return "下载后自动转换"
        case .manualOnly:    return "仅手动转换"
        case .disabled:      return "禁用"
        }
    }
}

// MARK: - AutoConvertManager

/// Orchestrates automatic doc2x conversion after a PDF download completes.
///
/// Configuration is persisted in `UserDefaults` under the key
/// `"auto_convert_mode"`.  Call `convertIfNeeded(paper:context:)` right after
/// `PDFCacheManager.download()` returns successfully.
enum AutoConvertManager {

    // MARK: Constants

    private static let modeKey = "auto_convert_mode"

    // MARK: Mode

    /// The currently selected conversion trigger mode.
    /// Reading and writing this property directly syncs with `UserDefaults`.
    static var mode: AutoConvertMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey) ?? ""
            return AutoConvertMode(rawValue: raw) ?? .manualOnly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    // MARK: Public API

    /// Converts the paper's PDF to Markdown via doc2x if the current mode allows it.
    ///
    /// - If mode is `.disabled`, this is a no-op.
    /// - If mode is `.afterDownload`, conversion starts immediately.
    /// - If mode is `.manualOnly`, this is a no-op (conversion must be triggered by the user).
    ///
    /// The `paper.convertStatus` is updated throughout the pipeline:
    ///   `.converting` while the task runs, `.completed` on success, `.failed` on error.
    ///
    /// - Parameters:
    ///   - paper: The `Paper` whose local PDF should be converted.
    ///   - context: The SwiftData context used to persist status updates.
    @MainActor
    static func convertIfNeeded(paper: Paper, context: ModelContext) async {
        guard mode == .afterDownload else { return }
        await performConversion(paper: paper, context: context)
    }

    // MARK: Private helpers

    @MainActor
    static func performConversion(paper: Paper, context: ModelContext) async {
        // Guard: only convert if a local PDF exists and has not already been converted.
        guard
            paper.isDownloaded,
            paper.convertStatus == .none || paper.convertStatus == .failed,
            let localPathString = paper.pdfLocalPath,
            !localPathString.isEmpty
        else { return }

        // Retrieve doc2x credentials.
        guard
            let apiKey = try? KeychainService.shared.retrieve(key: "doc2x_api_key"),
            !apiKey.isEmpty
        else { return }

        let baseURL = UserDefaults.standard.string(forKey: "doc2x_base_url")
            ?? Doc2xService.defaultBaseURL

        // Mark paper as converting.
        paper.convertStatus = .converting
        try? context.save()

        let service = Doc2xService(apiKey: apiKey, baseURL: baseURL)
        let pdfURL = URL(fileURLWithPath: localPathString)

        do {
            guard let pdfData = try? Data(contentsOf: pdfURL), !pdfData.isEmpty else {
                paper.convertStatus = .failed
                try? context.save()
                return
            }

            let markdown = try await service.convert(pdfData: pdfData)

            paper.markdownContent = markdown
            paper.convertStatus = .completed
            paper.markdownConvertedAt = .now
            try? context.save()
        } catch {
            paper.convertStatus = .failed
            try? context.save()
        }
    }
}
