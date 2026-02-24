import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(inverse: \Paper.tagItems)
    var papers: [Paper] = []

    init(name: String, colorHex: String = "6C5CE7", createdAt: Date = .now) {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
