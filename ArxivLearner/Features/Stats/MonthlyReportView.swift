import SwiftUI
import Charts
import SwiftData

// MARK: - MonthlyReportView

struct MonthlyReportView: View {

    let sessions: [ReadingSession]

    private var calendar: Calendar { Calendar.current }
    private let now = Date.now

    private var currentMonthSessions: [ReadingSession] {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }
        return sessions.filter { $0.startTime >= interval.start && $0.startTime < interval.end }
    }

    private var lastMonthSessions: [ReadingSession] {
        guard
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start,
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart),
            let lastMonthInterval = calendar.dateInterval(of: .month, for: lastMonthStart)
        else { return [] }
        return sessions.filter { $0.startTime >= lastMonthInterval.start && $0.startTime < lastMonthInterval.end }
    }

    private var currentPapers: Int {
        Set(currentMonthSessions.compactMap { $0.paper?.arxivId }).count
    }

    private var lastPapers: Int {
        Set(lastMonthSessions.compactMap { $0.paper?.arxivId }).count
    }

    private var currentDuration: TimeInterval {
        currentMonthSessions.reduce(0) { $0 + $1.duration }
    }

    private var lastDuration: TimeInterval {
        lastMonthSessions.reduce(0) { $0 + $1.duration }
    }

    private func percentChange(current: Double, last: Double) -> Double? {
        guard last > 0 else { return nil }
        return (current - last) / last * 100
    }

    private var categoryDistribution: [(category: String, duration: TimeInterval)] {
        var map: [String: TimeInterval] = [:]
        for session in currentMonthSessions {
            for cat in session.paper?.categories ?? [] {
                map[cat, default: 0] += session.duration
            }
        }
        return map.map { (category: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
    }

    private var dailyDurations: [MonthlyDailyData] {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }
        var result: [MonthlyDailyData] = []
        var current = interval.start
        while current < min(interval.end, now) {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            let daySessions = currentMonthSessions.filter {
                $0.startTime >= current && $0.startTime < nextDay
            }
            let duration = daySessions.reduce(0) { $0 + $1.duration }
            result.append(MonthlyDailyData(date: current, durationSeconds: duration))
            current = nextDay
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing) {
                summarySection
                Divider()
                comparisonSection
                Divider()
                if !categoryDistribution.isEmpty {
                    categorySection
                    Divider()
                }
                dailyLineChartSection
            }
            .padding()
        }
        .navigationTitle("本月报告")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.background)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本月概览")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: AppTheme.spacing) {
                StatCard(
                    title: "阅读论文",
                    value: "\(currentPapers)",
                    unit: "篇",
                    color: AppTheme.primary
                )
                StatCard(
                    title: "总阅读时长",
                    value: formatDuration(currentDuration),
                    unit: "",
                    color: AppTheme.secondary
                )
            }
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("与上月对比")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: AppTheme.spacing) {
                CompareCard(
                    title: "论文数",
                    current: Double(currentPapers),
                    last: Double(lastPapers),
                    formatter: { "\(Int($0))篇" }
                )
                CompareCard(
                    title: "阅读时长",
                    current: currentDuration / 60,
                    last: lastDuration / 60,
                    formatter: { "\(Int($0))分钟" }
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
                SectorMark(
                    angle: .value("时长", item.duration),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("分类", item.category))
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartLegend(position: .bottom, alignment: .center)
        }
    }

    // MARK: - Daily Line Chart

    private var dailyLineChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日阅读时长趋势")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if dailyDurations.isEmpty {
                Text("本月暂无阅读记录")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(dailyDurations) { item in
                    LineMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("分钟", item.durationSeconds / 60)
                    )
                    .foregroundStyle(AppTheme.primary.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("分钟", item.durationSeconds / 60)
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.15).gradient)
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))m")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CompareCard

private struct CompareCard: View {
    let title: String
    let current: Double
    let last: Double
    let formatter: (Double) -> String

    private var change: Double? {
        guard last > 0 else { return nil }
        return (current - last) / last * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(formatter(current))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
            if let pct = change {
                HStack(spacing: 2) {
                    Image(systemName: pct >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%.0f%%", abs(pct)))
                        .font(.caption2)
                }
                .foregroundStyle(pct >= 0 ? .green : .red)
            } else {
                Text("上月无数据")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }
}

// MARK: - MonthlyDailyData

private struct MonthlyDailyData: Identifiable {
    let date: Date
    let durationSeconds: TimeInterval
    var id: Date { date }
}

#Preview {
    NavigationStack {
        MonthlyReportView(sessions: [])
    }
}
