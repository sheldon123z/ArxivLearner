import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - ReadingStatsTests

final class ReadingStatsTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            Paper.self, ReadingSession.self, Tag.self,
            ChatMessage.self, Annotation.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Duration Calculation

    @MainActor
    func testDurationCalculation_withEndTime() throws {
        let start = Date(timeIntervalSinceNow: -300) // 5 minutes ago
        let end = Date(timeIntervalSinceNow: -60)    // 1 minute ago
        let session = ReadingSession(startTime: start, endTime: end, pagesRead: 3)
        context.insert(session)
        try context.save()

        let expectedDuration = end.timeIntervalSince(start)
        XCTAssertEqual(session.duration, expectedDuration, accuracy: 0.1,
                       "Duration should equal endTime - startTime")
    }

    @MainActor
    func testDurationCalculation_withoutEndTime_usesNow() throws {
        let start = Date(timeIntervalSinceNow: -120)
        let session = ReadingSession(startTime: start, endTime: nil, pagesRead: 0)
        context.insert(session)
        try context.save()

        // Duration should be approximately 120 seconds (allow generous tolerance)
        XCTAssertGreaterThan(session.duration, 100, "Open session duration should be > 100s")
        XCTAssertLessThan(session.duration, 200, "Open session duration should be < 200s")
    }

    @MainActor
    func testTotalDurationForPaper_sumsAllSessions() throws {
        let paper = Paper(arxivId: "2401.99001")
        context.insert(paper)

        let start1 = Date(timeIntervalSinceNow: -7200)
        let end1 = Date(timeIntervalSinceNow: -6300)  // 15 min
        let s1 = ReadingSession(startTime: start1, endTime: end1, paper: paper)

        let start2 = Date(timeIntervalSinceNow: -3600)
        let end2 = Date(timeIntervalSinceNow: -3000)  // 10 min
        let s2 = ReadingSession(startTime: start2, endTime: end2, paper: paper)

        context.insert(s1)
        context.insert(s2)
        paper.readingSessions = [s1, s2]
        try context.save()

        let total = paper.readingSessions.reduce(0) { $0 + $1.duration }
        XCTAssertEqual(total, s1.duration + s2.duration, accuracy: 0.1)
        XCTAssertGreaterThan(total, 1400, "Total should be > 1400s (~25 min)")
    }

    // MARK: - Heatmap Data Aggregation

    @MainActor
    func testHeatmapAggregation_groupsByDay() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Could not compute yesterday")
            return
        }

        // Two sessions today, one session yesterday
        let start1 = today.addingTimeInterval(600)
        let end1 = today.addingTimeInterval(1800)
        let s1 = ReadingSession(startTime: start1, endTime: end1)

        let start2 = today.addingTimeInterval(7200)
        let end2 = today.addingTimeInterval(8400)
        let s2 = ReadingSession(startTime: start2, endTime: end2)

        let start3 = yesterday.addingTimeInterval(3600)
        let end3 = yesterday.addingTimeInterval(5400)
        let s3 = ReadingSession(startTime: start3, endTime: end3)

        context.insert(s1)
        context.insert(s2)
        context.insert(s3)
        try context.save()

        let sessions = [s1, s2, s3]

        // Aggregate by day
        var durationByDay: [Date: TimeInterval] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)
            durationByDay[day, default: 0] += session.duration
        }

        XCTAssertEqual(durationByDay.keys.count, 2, "Should have 2 distinct days")
        let todayDuration = durationByDay[today] ?? 0
        let yesterdayDuration = durationByDay[yesterday] ?? 0
        XCTAssertGreaterThan(todayDuration, 0, "Today should have sessions")
        XCTAssertGreaterThan(yesterdayDuration, 0, "Yesterday should have sessions")
        XCTAssertGreaterThan(todayDuration, yesterdayDuration, "Today has 2 sessions vs 1")
    }

    // MARK: - Weekly Report Data

    @MainActor
    func testWeeklyReport_onlyIncludesCurrentWeek() throws {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date.now)?.start else {
            XCTFail("Could not compute week start")
            return
        }
        guard let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else {
            XCTFail("Could not compute last week start")
            return
        }

        // Session this week
        let thisWeekSession = ReadingSession(
            startTime: weekStart.addingTimeInterval(3600),
            endTime: weekStart.addingTimeInterval(7200)
        )
        // Session last week
        let lastWeekSession = ReadingSession(
            startTime: lastWeekStart.addingTimeInterval(3600),
            endTime: lastWeekStart.addingTimeInterval(5400)
        )

        context.insert(thisWeekSession)
        context.insert(lastWeekSession)
        try context.save()

        let allSessions = [thisWeekSession, lastWeekSession]
        let weekSessions = allSessions.filter {
            $0.startTime >= weekStart && $0.startTime <= Date.now
        }

        XCTAssertEqual(weekSessions.count, 1, "Only 1 session is in the current week")
        XCTAssertEqual(weekSessions.first?.startTime, thisWeekSession.startTime)
    }

    // MARK: - Monthly Report Data

    @MainActor
    func testMonthlyReport_comparesWithLastMonth() throws {
        let calendar = Calendar.current
        guard
            let thisMonthStart = calendar.dateInterval(of: .month, for: Date.now)?.start,
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: thisMonthStart),
            let lastMonthStart = calendar.dateInterval(of: .month, for: lastMonthDate)?.start
        else {
            XCTFail("Could not compute month intervals")
            return
        }

        let thisMonthSession = ReadingSession(
            startTime: thisMonthStart.addingTimeInterval(3600),
            endTime: thisMonthStart.addingTimeInterval(7200)
        )
        let lastMonthSession = ReadingSession(
            startTime: lastMonthStart.addingTimeInterval(3600),
            endTime: lastMonthStart.addingTimeInterval(5400)
        )

        context.insert(thisMonthSession)
        context.insert(lastMonthSession)
        try context.save()

        let allSessions = [thisMonthSession, lastMonthSession]
        guard
            let thisMonthInterval = calendar.dateInterval(of: .month, for: Date.now),
            let lastMonthInterval = calendar.dateInterval(of: .month, for: lastMonthDate)
        else { return }

        let thisMonth = allSessions.filter {
            $0.startTime >= thisMonthInterval.start && $0.startTime < thisMonthInterval.end
        }
        let lastMonth = allSessions.filter {
            $0.startTime >= lastMonthInterval.start && $0.startTime < lastMonthInterval.end
        }

        XCTAssertEqual(thisMonth.count, 1)
        XCTAssertEqual(lastMonth.count, 1)
        XCTAssertNotEqual(
            thisMonth.first?.startTime,
            lastMonth.first?.startTime,
            "Sessions should be in different months"
        )
    }

    // MARK: - Duration Formatter

    func testFormatDuration_lessThanHour_showsMinutes() {
        let result = formatDuration(25 * 60)
        XCTAssertTrue(result.contains("25"), "Should show 25 minutes")
    }

    func testFormatDuration_moreThanHour_showsHoursAndMinutes() {
        let result = formatDuration(90 * 60)
        XCTAssertTrue(result.contains("1"), "Should contain hour value 1")
        XCTAssertTrue(result.contains("30"), "Should contain minute value 30")
    }

    func testFormatDuration_zero() {
        let result = formatDuration(0)
        XCTAssertTrue(result.contains("0"), "Zero duration should show 0")
    }
}
