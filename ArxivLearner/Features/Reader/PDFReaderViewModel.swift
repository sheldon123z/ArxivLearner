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
