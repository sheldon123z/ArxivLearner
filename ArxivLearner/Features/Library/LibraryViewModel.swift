import Foundation
import SwiftData
import Observation

@Observable
final class LibraryViewModel {
    enum Filter: String, CaseIterable {
        case favorites = "收藏"
        case downloaded = "已下载"
        case all = "全部"
    }

    var selectedFilter: Filter = .favorites
}
