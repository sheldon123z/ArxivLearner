import Foundation
import SwiftData

// MARK: - ChatMessage

@Model
final class ChatMessage {
    var paper: Paper?
    var role: String
    var content: String
    var timestamp: Date

    init(
        paper: Paper? = nil,
        role: String = "user",
        content: String = "",
        timestamp: Date = .now
    ) {
        self.paper = paper
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
