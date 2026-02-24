import Foundation
import SwiftData
import Observation

@Observable
final class LibraryViewModel {
    enum Filter: String, CaseIterable {
        case favorites = "收藏"
        case downloaded = "已下载"
        case viewed = "已浏览"
        case all = "全部"
    }

    var selectedFilter: Filter = .favorites

    // MARK: - Viewed Papers Cleanup

    /// 清除 30 天前已标记为已浏览的论文的 viewedAt 标记
    func cleanupOldViewedPapers(modelContext: ModelContext) {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.viewedAt != nil }
        )

        guard let papers = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for paper in papers {
            if let viewedAt = paper.viewedAt, viewedAt < thirtyDaysAgo {
                paper.viewedAt = nil
                changed = true
            }
        }

        if changed {
            try? modelContext.save()
        }
    }
}
