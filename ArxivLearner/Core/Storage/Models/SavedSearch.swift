import Foundation
import SwiftData

@Model
final class SavedSearch {
    var name: String
    var query: String
    var filterCategory: String?
    var filterDateRange: String?
    var lastCheckedAt: Date?
    var lastResultCount: Int
    var isEnabled: Bool
    var createdAt: Date

    init(
        name: String,
        query: String,
        filterCategory: String? = nil,
        filterDateRange: String? = nil,
        lastCheckedAt: Date? = nil,
        lastResultCount: Int = 0,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.name = name
        self.query = query
        self.filterCategory = filterCategory
        self.filterDateRange = filterDateRange
        self.lastCheckedAt = lastCheckedAt
        self.lastResultCount = lastResultCount
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
