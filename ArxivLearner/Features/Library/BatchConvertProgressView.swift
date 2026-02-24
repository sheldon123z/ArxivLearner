import SwiftUI
import SwiftData

// MARK: - BatchConvertItem

struct BatchConvertItem: Identifiable {
    let id: String      // arxivId
    let title: String
    var status: Status

    enum Status {
        case pending
        case converting
        case done
        case failed(String)

        var icon: String {
            switch self {
            case .pending:   return "clock"
            case .converting: return "arrow.trianglehead.2.clockwise"
            case .done:      return "checkmark.circle.fill"
            case .failed:    return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .pending:   return .gray
            case .converting: return .orange
            case .done:      return .green
            case .failed:    return .red
            }
        }

        var label: String {
            switch self {
            case .pending:   return "等待中"
            case .converting: return "转换中"
            case .done:      return "已完成"
            case .failed(let msg): return "失败: \(msg)"
            }
        }
    }
}

// MARK: - BatchConvertManager

@Observable
final class BatchConvertManager {
    var items: [BatchConvertItem] = []
    var isCancelled = false
    var isRunning = false

    private var doc2xApiKey: String = ""
    private var doc2xBaseURL: String = ""

    init(papers: [Paper]) {
        doc2xApiKey = (try? KeychainService.shared.retrieve(key: "doc2x_api_key")) ?? ""
        doc2xBaseURL = UserDefaults.standard.string(forKey: "doc2x_base_url") ?? Doc2xService.defaultBaseURL

        items = papers.map {
            BatchConvertItem(id: $0.arxivId, title: $0.title, status: .pending)
        }
    }

    func start(papers: [Paper], modelContext: ModelContext) async {
        isRunning = true
        isCancelled = false

        let service = Doc2xService(apiKey: doc2xApiKey, baseURL: doc2xBaseURL)

        for i in items.indices {
            guard !isCancelled else { break }

            let arxivId = items[i].id
            guard let paper = papers.first(where: { $0.arxivId == arxivId }),
                  paper.isDownloaded,
                  let localPath = paper.pdfLocalPath else {
                items[i].status = .failed("未下载")
                continue
            }

            guard let pdfData = try? Data(contentsOf: URL(fileURLWithPath: localPath)) else {
                items[i].status = .failed("读取文件失败")
                continue
            }

            items[i].status = .converting

            do {
                let markdown = try await service.convert(pdfData: pdfData)
                paper.markdownContent = markdown
                paper.convertStatus = .completed
                paper.markdownConvertedAt = .now
                try? modelContext.save()

                // Update usage stats
                let pageCount = estimatePageCount(from: markdown)
                ConversionStats.addPages(pageCount)

                items[i].status = .done
            } catch {
                paper.convertStatus = .failed
                items[i].status = .failed(error.localizedDescription)
            }
        }

        isRunning = false
    }

    func cancel() {
        isCancelled = true
    }

    var completedCount: Int {
        items.filter { if case .done = $0.status { return true } else { return false } }.count
    }

    var totalCount: Int { items.count }
    var isAllDone: Bool { !isRunning || isCancelled }

    private func estimatePageCount(from markdown: String) -> Int {
        max(1, markdown.count / 2000)
    }
}

// MARK: - ConversionStats (AppStorage-based tracker)

enum ConversionStats {
    static func addPages(_ count: Int) {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let storedMonth = UserDefaults.standard.integer(forKey: "conversion_stats_month")
        let storedYear = UserDefaults.standard.integer(forKey: "conversion_stats_year")

        if storedMonth == currentMonth && storedYear == currentYear {
            let existing = UserDefaults.standard.integer(forKey: "conversion_stats_monthly_pages")
            UserDefaults.standard.set(existing + count, forKey: "conversion_stats_monthly_pages")
        } else {
            UserDefaults.standard.set(count, forKey: "conversion_stats_monthly_pages")
            UserDefaults.standard.set(currentMonth, forKey: "conversion_stats_month")
            UserDefaults.standard.set(currentYear, forKey: "conversion_stats_year")
        }

        let total = UserDefaults.standard.integer(forKey: "conversion_stats_total_pages")
        UserDefaults.standard.set(total + count, forKey: "conversion_stats_total_pages")
    }

    static var monthlyPages: Int {
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let storedMonth = UserDefaults.standard.integer(forKey: "conversion_stats_month")
        let storedYear = UserDefaults.standard.integer(forKey: "conversion_stats_year")
        guard storedMonth == currentMonth && storedYear == currentYear else { return 0 }
        return UserDefaults.standard.integer(forKey: "conversion_stats_monthly_pages")
    }

    static var totalPages: Int {
        UserDefaults.standard.integer(forKey: "conversion_stats_total_pages")
    }
}

// MARK: - BatchConvertProgressView

struct BatchConvertProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let papers: [Paper]
    @State private var manager: BatchConvertManager

    init(papers: [Paper]) {
        self.papers = papers
        _manager = State(initialValue: BatchConvertManager(papers: papers))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress header
                VStack(spacing: 8) {
                    ProgressView(value: Double(manager.completedCount), total: Double(manager.totalCount))
                        .tint(AppTheme.secondary)
                        .padding(.horizontal)

                    Text("已完成 \(manager.completedCount)/\(manager.totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 16)
                .background(AppTheme.cardBackground)

                // Paper list
                List {
                    ForEach(manager.items) { item in
                        HStack(spacing: 12) {
                            if case .converting = item.status {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: item.status.icon)
                                    .foregroundStyle(item.status.color)
                                    .frame(width: 20, height: 20)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(item.status.label)
                                    .font(.caption)
                                    .foregroundStyle(item.status.color)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("批量转换 MD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if manager.isRunning && !manager.isCancelled {
                        Button("取消") {
                            manager.cancel()
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
            }
            .task {
                await manager.start(papers: papers, modelContext: modelContext)
            }
            .onChange(of: manager.isRunning) { _, running in
                if !running {
                    // Auto-dismiss after 1.5s when all complete (not cancelled)
                    if !manager.isCancelled {
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            await MainActor.run { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BatchConvertProgressView(papers: [])
        .modelContainer(for: Paper.self, inMemory: true)
}
