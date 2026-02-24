import SwiftUI
import Charts
import SwiftData

// MARK: - WeeklyReportView

struct WeeklyReportView: View {

    let sessions: [ReadingSession]

    private var calendar: Calendar { Calendar.current }

    private var weekSessions: [ReadingSession] {
        let now = Date.now
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        return sessions.filter { $0.startTime >= weekStart && $0.startTime <= now }
    }

    private var uniquePapersThisWeek: Int {
        Set(weekSessions.compactMap { $0.paper?.arxivId }).count
    }

    private var totalDurationSeconds: TimeInterval {
        weekSessions.reduce(0) { $0 + $1.duration }
    }

    private var formattedDuration: String {
        formatDuration(totalDurationSeconds)
    }

    private var categoryDistribution: [(category: String, count: Int)] {
        var counts: [String: Int] = [:]
        for session in weekSessions {
            for cat in session.paper?.categories ?? [] {
                counts[cat, default: 0] += 1
            }
        }
        return counts.map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var dailyDurations: [DailyDuration] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date.now)?.start else {
            return []
        }
        return (0..<7).compactMap { offset -> DailyDuration? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            if date > Date.now { return nil }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            let daySessions = weekSessions.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }
            let duration = daySessions.reduce(0) { $0 + $1.duration }
            let label = date.formatted(.dateTime.weekday(.abbreviated))
            return DailyDuration(date: date, label: label, durationSeconds: duration)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                // Summary cards
                summarySection

                Divider()

                // Category distribution
                if !categoryDistribution.isEmpty {
                    categorySection
                    Divider()
                }

                // Daily bar chart
                dailyTrendSection
            }
            .padding()
        }
        .navigationTitle("本周报告")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周概览")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: AppTheme.spacing) {
                StatCard(
                    title: "阅读论文",
                    value: "\(uniquePapersThisWeek)",
                    unit: "篇",
                    color: AppTheme.primary
                )
                StatCard(
                    title: "总阅读时长",
                    value: formattedDuration,
                    unit: "",
                    color: AppTheme.secondary
                )
            }
        }
    }

    // MARK: - Category Distribution

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类分布")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Chart(categoryDistribution, id: \.category) { item in
                BarMark(
                    x: .value("次数", item.count),
                    y: .value("分类", item.category)
                )
                .foregroundStyle(AppTheme.primary.gradient)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(max(80, categoryDistribution.count * 36)))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
        }
    }

    // MARK: - Daily Trend

    private var dailyTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日阅读时长")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if dailyDurations.isEmpty {
                Text("本周暂无阅读记录")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(dailyDurations) { item in
                    BarMark(
                        x: .value("日期", item.label),
                        y: .value("分钟", item.durationSeconds / 60)
                    )
                    .foregroundStyle(AppTheme.secondary.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))分")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

private struct DailyDuration: Identifiable {
    let date: Date
    let label: String
    let durationSeconds: TimeInterval
    var id: Date { date }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}

// MARK: - Duration Formatter

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
        return "\(hours)h\(minutes)m"
    }
    return "\(minutes)分钟"
}

#Preview {
    NavigationStack {
        WeeklyReportView(sessions: [])
    }
}
