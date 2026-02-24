import Foundation
import SwiftData

@Model
final class SearchHistory {
    var query: String
    var filterCategory: String?
    var filterDateRange: String?
    var timestamp: Date

    init(
        query: String,
        filterCategory: String? = nil,
        filterDateRange: String? = nil,
        timestamp: Date = .now
    ) {
        self.query = query
        self.filterCategory = filterCategory
        self.filterDateRange = filterDateRange
        self.timestamp = timestamp
    }
}
