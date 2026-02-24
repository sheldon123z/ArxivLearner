import Foundation
import SwiftData

@Model
final class ReadingSession {
    var startTime: Date
    var endTime: Date?
    var pagesRead: Int

    @Relationship var paper: Paper?

    var duration: TimeInterval {
        guard let endTime else { return Date.now.timeIntervalSince(startTime) }
        return endTime.timeIntervalSince(startTime)
    }

    init(
        startTime: Date = .now,
        endTime: Date? = nil,
        pagesRead: Int = 0,
        paper: Paper? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.pagesRead = pagesRead
        self.paper = paper
    }
}
