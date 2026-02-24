import Foundation
import PDFKit
import Observation
import SwiftData

// MARK: - SelectionAction

enum SelectionAction {
    case translate
    case explain
}

// MARK: - OutlineItem

struct OutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int
    let indentLevel: Int
    let children: [OutlineItem]
}

// MARK: - HighlightColor

enum HighlightColor: String, CaseIterable {
    case yellow = "FDCB6E"
    case green  = "00B894"
    case blue   = "0984E3"
    case pink   = "FD79A8"

    var displayName: String {
        switch self {
        case .yellow: return "黄色"
        case .green:  return "绿色"
        case .blue:   return "蓝色"
        case .pink:   return "粉色"
        }
    }
}

// MARK: - PDFReaderViewModel

@Observable
final class PDFReaderViewModel {

    // MARK: Document State

    var pdfDocument: PDFDocument?
    var currentPage: Int = 0
    var totalPages: Int = 0
    var isLoading = false
    var errorMessage: String?

    // MARK: Text Selection State

    var selectedText: String = ""
    var showSelectionToolbar: Bool = false
    var showHighlightColors: Bool = false

    // MARK: LLM Panel State

    var llmResult: String = ""
    var isLLMLoading: Bool = false
    var llmError: String? = nil
    var showLLMPanel: Bool = false
    var llmPanelTitle: String = ""

    // MARK: Chat State

    var showChatWithSelection: Bool = false
    var showChatPanel: Bool = false
    var quotedText: String = ""

    // MARK: Bookmarks

    var bookmarks: [Int] = []
    var showBookmarksSheet: Bool = false

    // MARK: Annotations

    var annotations: [Annotation] = []
    var showAnnotationList: Bool = false
    var noteEditAnnotation: Annotation? = nil
    var noteEditText: String = ""
    var pendingNotePageIndex: Int = 0
    var pendingNoteRect: CGRect = .zero

    // MARK: Outline

    var outlineItems: [OutlineItem] = []
    var showOutlinePanel: Bool = false

    // MARK: Dark Mode

    var pdfDarkMode: Bool = false

    // MARK: Reading Session

    var currentReadingSession: ReadingSession?

    // MARK: Private

    private var bookmarksKey: String = ""
    private var modelContext: ModelContext?
    private var currentPaper: Paper?

    // MARK: PDF Loading

    func loadPDF(from url: URL, paper: Paper? = nil, context: ModelContext? = nil) {
        isLoading = true
        bookmarksKey = "bookmarks_\(url.lastPathComponent)"
        self.modelContext = context
        self.currentPaper = paper
        loadBookmarks()

        if let doc = PDFDocument(url: url) {
            pdfDocument = doc
            totalPages = doc.pageCount
            parseOutline(from: doc)
        } else {
            errorMessage = "无法加载 PDF 文件"
        }
        isLoading = false

        if let paper, let context {
            loadAnnotations(paper: paper, context: context)
        }
    }

    func loadPDF(from data: Data) {
        isLoading = true
        if let doc = PDFDocument(data: data) {
            pdfDocument = doc
            totalPages = doc.pageCount
            parseOutline(from: doc)
        } else {
            errorMessage = "无法解析 PDF 数据"
        }
        isLoading = false
    }

    // MARK: - Selection Actions

    func handleSelection(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            selectedText = ""
            showSelectionToolbar = false
            showHighlightColors = false
            return
        }
        selectedText = trimmed
        showSelectionToolbar = true
        showHighlightColors = false
    }

    func copySelection() {
        UIPasteboard.general.string = selectedText
        dismissSelectionToolbar()
    }

    func translateSelection(using service: LLMServiceProtocol?) {
        Task { @MainActor in
            await runLLM(
                service: service,
                systemPrompt: "你是一名专业翻译，请将以下文本翻译为中文，保持学术风格，只输出译文。",
                userContent: selectedText,
                panelTitle: "翻译"
            )
        }
        dismissSelectionToolbar()
    }

    func explainSelection(using service: LLMServiceProtocol?) {
        Task { @MainActor in
            await runLLM(
                service: service,
                systemPrompt: "你是一名学术助手，请用中文简洁解释以下内容，适合研究生阅读。",
                userContent: selectedText,
                panelTitle: "解释"
            )
        }
        dismissSelectionToolbar()
    }

    func askWithSelection() {
        showChatWithSelection = true
        dismissSelectionToolbar()
    }

    func quoteInChat() {
        quotedText = selectedText
        showChatPanel = true
        dismissSelectionToolbar()
    }

    func dismissSelectionToolbar() {
        showSelectionToolbar = false
        showHighlightColors = false
    }

    // MARK: - Highlight Annotation

    func addHighlight(color: HighlightColor, selection: PDFSelection?, context: ModelContext?) {
        guard let paper = currentPaper,
              let context = context ?? modelContext,
              let pdfDoc = pdfDocument else { return }

        guard let sel = selection,
              let firstPage = sel.pages.first,
              let pdfPage = firstPage as? PDFPage else { return }

        let pageIndex = pdfDoc.index(for: pdfPage)
        let bounds = sel.bounds(for: pdfPage)

        let annotation = Annotation(
            type: .highlight,
            pageIndex: pageIndex,
            rectX: Double(bounds.origin.x),
            rectY: Double(bounds.origin.y),
            rectWidth: Double(bounds.size.width),
            rectHeight: Double(bounds.size.height),
            colorHex: color.rawValue,
            text: sel.string ?? selectedText,
            paper: paper
        )
        context.insert(annotation)
        annotations.append(annotation)
        try? context.save()

        // Apply native PDFAnnotation highlight
        let pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        pdfAnnotation.color = UIColor(hex: color.rawValue).withAlphaComponent(0.4)
        pdfPage.addAnnotation(pdfAnnotation)

        dismissSelectionToolbar()
    }

    // MARK: - Note Annotation

    func addNoteAnnotation(pageIndex: Int, rect: CGRect, context: ModelContext?) {
        guard let paper = currentPaper,
              let ctx = context ?? modelContext else { return }

        let annotation = Annotation(
            type: .note,
            pageIndex: pageIndex,
            rectX: Double(rect.origin.x),
            rectY: Double(rect.origin.y),
            rectWidth: Double(rect.size.width),
            rectHeight: Double(rect.size.height),
            colorHex: "FDCB6E",
            text: "",
            paper: paper
        )
        ctx.insert(annotation)
        annotations.append(annotation)
        try? ctx.save()

        noteEditAnnotation = annotation
        noteEditText = ""
    }

    func saveNoteText(context: ModelContext?) {
        guard let ann = noteEditAnnotation else { return }
        ann.text = noteEditText
        try? (context ?? modelContext)?.save()
        noteEditAnnotation = nil
        noteEditText = ""
    }

    func deleteAnnotation(_ annotation: Annotation, context: ModelContext?) {
        guard let ctx = context ?? modelContext else { return }
        annotations.removeAll { $0.persistentModelID == annotation.persistentModelID }
        ctx.delete(annotation)
        try? ctx.save()
    }

    // MARK: - Load Annotations

    func loadAnnotations(paper: Paper, context: ModelContext) {
        let arxivId = paper.arxivId
        var descriptor = FetchDescriptor<Annotation>(
            predicate: #Predicate { $0.paper?.arxivId == arxivId },
            sortBy: [SortDescriptor(\.pageIndex), SortDescriptor(\.rectY)]
        )
        descriptor.relationshipKeyPathsForPrefetching = []
        annotations = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Outline Parsing

    private func parseOutline(from doc: PDFDocument) {
        guard let root = doc.outlineRoot else {
            outlineItems = []
            return
        }
        outlineItems = buildOutlineItems(from: root, doc: doc, level: 0)
    }

    private func buildOutlineItems(from outline: PDFOutline, doc: PDFDocument, level: Int) -> [OutlineItem] {
        var items: [OutlineItem] = []
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let title = child.label ?? "无标题"
            let pageIndex: Int
            if let dest = child.destination, let page = dest.page {
                pageIndex = doc.index(for: page)
            } else {
                pageIndex = 0
            }
            let children = buildOutlineItems(from: child, doc: doc, level: level + 1)
            items.append(OutlineItem(title: title, pageIndex: pageIndex, indentLevel: level, children: children))
        }
        return items
    }

    // MARK: - Reading Session

    func startReadingSession(paper: Paper, context: ModelContext) {
        let session = ReadingSession(startTime: .now, paper: paper)
        context.insert(session)
        try? context.save()
        currentReadingSession = session
    }

    func endReadingSession(context: ModelContext) {
        guard let session = currentReadingSession else { return }
        session.endTime = .now
        session.pagesRead = totalPages > 0 ? currentPage + 1 : 0
        try? context.save()
        currentReadingSession = nil
    }

    // MARK: - Private LLM Runner

    @MainActor
    private func runLLM(
        service: LLMServiceProtocol?,
        systemPrompt: String,
        userContent: String,
        panelTitle: String
    ) async {
        guard let service else {
            llmError = "请先在设置中配置 LLM 服务"
            llmPanelTitle = panelTitle
            showLLMPanel = true
            return
        }

        llmPanelTitle = panelTitle
        llmResult = ""
        llmError = nil
        isLLMLoading = true
        showLLMPanel = true

        let messages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: userContent)
        ]

        do {
            for try await chunk in service.completeStream(messages: messages) {
                llmResult += chunk
            }
        } catch {
            llmError = "请求失败: \(error.localizedDescription)"
        }

        isLLMLoading = false
    }

    // MARK: - Bookmarks

    func toggleBookmark(page: Int) {
        if bookmarks.contains(page) {
            bookmarks.removeAll { $0 == page }
        } else {
            bookmarks.append(page)
            bookmarks.sort()
        }
        saveBookmarks()
    }

    func isBookmarked(page: Int) -> Bool {
        bookmarks.contains(page)
    }

    private func loadBookmarks() {
        bookmarks = UserDefaults.standard.array(forKey: bookmarksKey)
            .flatMap { $0 as? [Int] } ?? []
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
