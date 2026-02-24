import SwiftUI
import PDFKit
import SwiftData

// MARK: - PDFReaderView

struct PDFReaderView: View {
    let title: String
    let pdfURL: URL
    var paper: Paper? = nil

    @State private var viewModel = PDFReaderViewModel()
    @State private var llmService: (any LLMServiceProtocol)?
    @State private var pdfViewRef: PDFView? = nil
    @State private var showNoteEditor: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // PDF content area
                    pdfContentArea
                        .frame(width: viewModel.showChatPanel
                               ? geo.size.width * 0.6
                               : geo.size.width)

                    // Side chat panel (40% width)
                    if viewModel.showChatPanel, let p = paper {
                        Divider()
                        SideChatPanelView(paper: p, quotedText: $viewModel.quotedText)
                            .frame(width: geo.size.width * 0.4)
                            .transition(.move(edge: .trailing))
                            .environment(\.modelContext, modelContext)
                    }
                }
                .animation(.spring(duration: 0.3), value: viewModel.showChatPanel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        // LLM result panel
        .sheet(isPresented: $viewModel.showLLMPanel) {
            LLMResultPanel(
                title: viewModel.llmPanelTitle,
                result: viewModel.llmResult,
                isLoading: viewModel.isLLMLoading,
                errorMessage: viewModel.llmError
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Bookmarks sheet
        .sheet(isPresented: $viewModel.showBookmarksSheet) {
            bookmarksSheet
        }
        // Annotation list sheet
        .sheet(isPresented: $viewModel.showAnnotationList) {
            AnnotationListView(
                annotations: viewModel.annotations,
                onJumpToPage: { page in
                    jumpToPageIndex(page)
                    viewModel.showAnnotationList = false
                },
                onDelete: { ann in
                    viewModel.deleteAnnotation(ann, context: modelContext)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Outline sheet
        .sheet(isPresented: $viewModel.showOutlinePanel) {
            OutlineView(items: viewModel.outlineItems) { page in
                jumpToPageIndex(page)
                viewModel.showOutlinePanel = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Note editor popover
        .sheet(isPresented: $showNoteEditor, onDismiss: {
            viewModel.saveNoteText(context: modelContext)
        }) {
            noteEditorSheet
        }
        .onAppear {
            viewModel.loadPDF(from: pdfURL, paper: paper, context: modelContext)
            viewModel.pdfDarkMode = AppearanceManager.shared.pdfDarkMode
            loadLLMService()
            if let p = paper {
                viewModel.startReadingSession(paper: p, context: modelContext)
            }
        }
        .onDisappear {
            viewModel.endReadingSession(context: modelContext)
            AppearanceManager.shared.pdfDarkMode = viewModel.pdfDarkMode
        }
        .onChange(of: viewModel.noteEditAnnotation) { _, newValue in
            if newValue != nil {
                showNoteEditor = true
            }
        }
    }

    // MARK: - PDF Content Area

    private var pdfContentArea: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if let doc = viewModel.pdfDocument {
                PDFKitView(
                    document: doc,
                    darkMode: viewModel.pdfDarkMode,
                    annotations: viewModel.annotations,
                    onSelectionChanged: { text, selection in
                        viewModel.handleSelection(text)
                    },
                    onPageChanged: { page in
                        viewModel.currentPage = page
                    },
                    onLongPress: { pageIndex, rect in
                        viewModel.pendingNotePageIndex = pageIndex
                        viewModel.pendingNoteRect = rect
                        viewModel.addNoteAnnotation(pageIndex: pageIndex, rect: rect, context: modelContext)
                    },
                    onPDFViewCreated: { pdfView in
                        pdfViewRef = pdfView
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }

            // Floating selection toolbar
            if viewModel.showSelectionToolbar && !viewModel.selectedText.isEmpty {
                if viewModel.showHighlightColors {
                    highlightColorPicker
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    selectionToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.28), value: viewModel.showSelectionToolbar)
        .animation(.spring(duration: 0.2), value: viewModel.showHighlightColors)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("返回") { dismiss() }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            // Page indicator
            if viewModel.totalPages > 0 {
                Text("第 \(viewModel.currentPage + 1) / \(viewModel.totalPages) 页")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // PDF dark mode toggle
            Button {
                viewModel.pdfDarkMode.toggle()
                AppearanceManager.shared.pdfDarkMode = viewModel.pdfDarkMode
            } label: {
                Image(systemName: viewModel.pdfDarkMode ? "moon.fill" : "moon")
                    .foregroundStyle(viewModel.pdfDarkMode ? AppTheme.accent : AppTheme.primary)
            }

            // Outline button
            Button {
                viewModel.showOutlinePanel = true
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(AppTheme.primary)
            }
            .disabled(viewModel.outlineItems.isEmpty)

            // Annotation list button
            Button {
                viewModel.showAnnotationList = true
            } label: {
                Image(systemName: "pencil.and.list.clipboard")
                    .foregroundStyle(AppTheme.primary)
            }

            // AI chat panel toggle
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.showChatPanel.toggle()
                }
            } label: {
                Image(systemName: viewModel.showChatPanel ? "brain.fill" : "brain")
                    .foregroundStyle(viewModel.showChatPanel ? AppTheme.accent : AppTheme.primary)
            }
            .disabled(paper == nil)

            // Bookmark
            bookmarkButton
            bookmarksListButton
        }
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "doc.on.doc", label: "复制") {
                viewModel.copySelection()
            }
            Divider().frame(height: 36)
            toolbarButton(icon: "globe", label: "翻译") {
                viewModel.translateSelection(using: llmService)
            }
            Divider().frame(height: 36)
            toolbarButton(icon: "lightbulb", label: "解释") {
                viewModel.explainSelection(using: llmService)
            }
            Divider().frame(height: 36)
            toolbarButton(icon: "highlighter", label: "高亮") {
                viewModel.showHighlightColors = true
            }
            if paper != nil {
                Divider().frame(height: 36)
                toolbarButton(icon: "quote.bubble", label: "引用") {
                    viewModel.quoteInChat()
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Highlight Color Picker

    private var highlightColorPicker: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases, id: \.rawValue) { color in
                Button {
                    if let pdfView = pdfViewRef {
                        viewModel.addHighlight(
                            color: color,
                            selection: pdfView.currentSelection,
                            context: modelContext
                        )
                    }
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: color.rawValue))
                            .frame(width: 28, height: 28)
                            .shadow(color: Color(hex: color.rawValue).opacity(0.4), radius: 4)
                        Text(color.displayName)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            Divider().frame(height: 36)
            Button {
                viewModel.showHighlightColors = false
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("取消")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func toolbarButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(AppTheme.primary)
            .frame(width: 72, height: 52)
        }
    }

    // MARK: - Note Editor Sheet

    private var noteEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                Text("第 \(viewModel.pendingNotePageIndex + 1) 页")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal)

                TextEditor(text: $viewModel.noteEditText)
                    .font(.body)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                    .padding(.horizontal)
                    .frame(minHeight: 120)

                Spacer()
            }
            .navigationTitle("添加注释")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        viewModel.noteEditAnnotation = nil
                        viewModel.noteEditText = ""
                        showNoteEditor = false
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        showNoteEditor = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Bookmark Toolbar Buttons

    private var bookmarkButton: some View {
        Button {
            viewModel.toggleBookmark(page: viewModel.currentPage)
        } label: {
            Image(systemName: viewModel.isBookmarked(page: viewModel.currentPage)
                  ? "bookmark.fill"
                  : "bookmark")
            .foregroundStyle(
                viewModel.isBookmarked(page: viewModel.currentPage)
                ? AppTheme.accent
                : AppTheme.primary
            )
        }
    }

    private var bookmarksListButton: some View {
        Button {
            viewModel.showBookmarksSheet = true
        } label: {
            Image(systemName: "list.bullet.below.rectangle")
                .foregroundStyle(AppTheme.primary)
        }
        .disabled(viewModel.bookmarks.isEmpty)
    }

    // MARK: - Bookmarks Sheet

    private var bookmarksSheet: some View {
        NavigationStack {
            Group {
                if viewModel.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "暂无书签",
                        systemImage: "bookmark",
                        description: Text("点击工具栏书签按钮收藏当前页")
                    )
                } else {
                    List {
                        ForEach(viewModel.bookmarks, id: \.self) { page in
                            Button {
                                jumpToPageIndex(page)
                                viewModel.showBookmarksSheet = false
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    Text("第 \(page + 1) 页")
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { i in
                                let page = viewModel.bookmarks[i]
                                viewModel.toggleBookmark(page: page)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("书签列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { viewModel.showBookmarksSheet = false }
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func jumpToPageIndex(_ page: Int) {
        guard let doc = viewModel.pdfDocument,
              let pdfPage = doc.page(at: page) else { return }
        NotificationCenter.default.post(
            name: .pdfReaderJumpToPage,
            object: pdfPage
        )
    }

    private func loadLLMService() {
        guard
            let data = UserDefaults.standard.data(forKey: "llm_config"),
            let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: data),
            let apiKey = try? KeychainService.shared.retrieve(key: "llm_api_key"),
            !apiKey.isEmpty
        else { return }

        let resolvedConfig = LLMProviderConfig(
            providerId: config.providerId,
            name: config.name,
            baseURL: config.baseURL,
            apiKey: apiKey,
            modelId: config.modelId
        )
        llmService = OpenAICompatibleService(config: resolvedConfig)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let pdfReaderJumpToPage = Notification.Name("pdfReaderJumpToPage")
}

// MARK: - PDFKitView

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    var darkMode: Bool = false
    var annotations: [Annotation] = []
    var onSelectionChanged: (String, PDFSelection?) -> Void
    var onPageChanged: (Int) -> Void
    var onLongPress: ((Int, CGRect) -> Void)?
    var onPDFViewCreated: ((PDFView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChanged: onSelectionChanged,
            onPageChanged: onPageChanged,
            onLongPress: onLongPress
        )
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        // Selection notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        // Page-change notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // Jump-to-page notification
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.jumpToPage(_:)),
            name: .pdfReaderJumpToPage,
            object: nil
        )

        // Long press gesture for note annotation
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.7
        pdfView.addGestureRecognizer(longPress)

        context.coordinator.pdfView = pdfView

        // Apply dark mode
        applyDarkMode(darkMode, to: pdfView)

        // Apply existing annotations
        applyAnnotations(to: document)

        onPDFViewCreated?(pdfView)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
            applyAnnotations(to: document)
        }
        applyDarkMode(darkMode, to: uiView)
    }

    // MARK: - Dark Mode

    private func applyDarkMode(_ enabled: Bool, to pdfView: PDFView) {
        if enabled {
            pdfView.backgroundColor = .black
            // Apply color invert filter
            let filter = CIFilter(name: "CIColorInvert")
            pdfView.layer.filters = filter.map { [$0] }
        } else {
            pdfView.backgroundColor = UIColor.systemBackground
            pdfView.layer.filters = nil
        }
    }

    // MARK: - Apply Annotations

    private func applyAnnotations(to doc: PDFDocument) {
        // Apply highlight annotations stored in SwiftData
        for annotation in annotations {
            guard annotation.annotationType == .highlight,
                  let page = doc.page(at: annotation.pageIndex) else { continue }

            let bounds = CGRect(
                x: annotation.rectX,
                y: annotation.rectY,
                width: annotation.rectWidth,
                height: annotation.rectHeight
            )

            // Check if already applied
            let existing = page.annotations.filter { $0.type == PDFAnnotationSubtype.highlight.rawValue }
            let alreadyExists = existing.contains { abs($0.bounds.origin.x - bounds.origin.x) < 1 }
            guard !alreadyExists else { continue }

            let pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            pdfAnnotation.color = UIColor(hex: annotation.colorHex).withAlphaComponent(0.4)
            page.addAnnotation(pdfAnnotation)
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        var onSelectionChanged: (String, PDFSelection?) -> Void
        var onPageChanged: (Int) -> Void
        var onLongPress: ((Int, CGRect) -> Void)?
        weak var pdfView: PDFView?

        init(
            onSelectionChanged: @escaping (String, PDFSelection?) -> Void,
            onPageChanged: @escaping (Int) -> Void,
            onLongPress: ((Int, CGRect) -> Void)?
        ) {
            self.onSelectionChanged = onSelectionChanged
            self.onPageChanged = onPageChanged
            self.onLongPress = onLongPress
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            let selection = pdfView.currentSelection
            let text = selection?.string ?? ""
            DispatchQueue.main.async {
                self.onSelectionChanged(text, selection)
            }
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let pageIndex = doc.index(for: currentPage)
            DispatchQueue.main.async {
                self.onPageChanged(pageIndex)
            }
        }

        @objc func jumpToPage(_ notification: Notification) {
            guard
                let page = notification.object as? PDFPage,
                let pdfView = pdfView
            else { return }
            DispatchQueue.main.async {
                pdfView.go(to: page)
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let pdfView = pdfView else { return }

            let point = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: point, nearest: true) else { return }
            guard let doc = pdfView.document else { return }

            let pageIndex = doc.index(for: page)
            let pagePoint = pdfView.convert(point, to: page)
            let tapRect = CGRect(x: pagePoint.x - 10, y: pagePoint.y - 10, width: 20, height: 20)

            DispatchQueue.main.async {
                self.onLongPress?(pageIndex, tapRect)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - LLMResultPanel

struct LLMResultPanel: View {
    let title: String
    let result: String
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isLoading && result.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("正在生成…")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if let err = errorMessage {
                        Text(err)
                            .foregroundStyle(.red)
                            .padding(AppTheme.cardPadding)
                    } else {
                        Text(result)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(AppTheme.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = result
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .disabled(result.isEmpty)
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}
