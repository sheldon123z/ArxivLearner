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
                            .foregroundStyle(.secondary)
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
