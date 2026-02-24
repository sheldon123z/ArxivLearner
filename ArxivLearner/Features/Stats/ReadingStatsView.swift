import SwiftUI
import SwiftData

// MARK: - ReadingStatsView

struct ReadingStatsView: View {

    @Query(sort: \ReadingSession.startTime, order: .reverse)
    private var allSessions: [ReadingSession]

    @State private var showWeeklyReport = false
    @State private var showMonthlyReport = false

    private var calendar: Calendar { Calendar.current }
    private let now = Date.now

    private var weekSessions: [ReadingSession] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        return allSessions.filter { $0.startTime >= weekStart && $0.startTime <= now }
    }

    private var weekPapersCount: Int {
        Set(weekSessions.compactMap { $0.paper?.arxivId }).count
    }

    private var weekTotalDuration: TimeInterval {
        weekSessions.reduce(0) { $0 + $1.duration }
    }

    private var mostFrequentCategory: String {
        var counts: [String: Int] = [:]
        for session in weekSessions {
            for cat in session.paper?.categories ?? [] {
                counts[cat, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "暂无"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    // Summary cards
                    summarySection

                    // Heatmap
                    heatmapSection

                    // Report buttons
                    reportButtonsSection
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("阅读统计")
            .navigationDestination(isPresented: $showWeeklyReport) {
                WeeklyReportView(sessions: allSessions)
            }
            .navigationDestination(isPresented: $showMonthlyReport) {
                MonthlyReportView(sessions: allSessions)
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周概况")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacing) {
                StatCard(
                    title: "本周阅读",
                    value: "\(weekPapersCount)",
                    unit: "篇",
                    color: AppTheme.primary
                )
                StatCard(
                    title: "本周总时长",
                    value: formatDuration(weekTotalDuration),
                    unit: "",
                    color: AppTheme.secondary
                )
                StatCard(
                    title: "最常分类",
                    value: mostFrequentCategory,
                    unit: "",
                    color: AppTheme.accent
                )
                StatCard(
                    title: "阅读次数",
                    value: "\(weekSessions.count)",
                    unit: "次",
                    color: Color(hex: "E17055")
                )
            }
        }
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("阅读热力图（近 12 周）")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            CalendarHeatmapView(sessions: allSessions)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }
    }

    // MARK: - Report Buttons

    private var reportButtonsSection: some View {
        VStack(spacing: AppTheme.spacing) {
            Button {
                showWeeklyReport = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("查看本周报告")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }

            Button {
                showMonthlyReport = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("查看本月报告")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            }
        }
    }
}

#Preview {
    ReadingStatsView()
        .modelContainer(for: [ReadingSession.self, Paper.self], inMemory: true)
}
