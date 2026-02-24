import SwiftUI
import Charts
import SwiftData

// MARK: - HeatmapDay

struct HeatmapDay: Identifiable {
    let date: Date
    let weekIndex: Int   // 0 = oldest week
    let dayOfWeek: Int   // 0 = Monday, 6 = Sunday
    let totalDuration: TimeInterval  // seconds

    var id: Date { date }

    var intensityLevel: Int {
        switch totalDuration {
        case 0:          return 0
        case ..<300:     return 1   // < 5 min
        case ..<900:     return 2   // < 15 min
        case ..<1800:    return 3   // < 30 min
        default:         return 4
        }
    }
}

// MARK: - CalendarHeatmapView

struct CalendarHeatmapView: View {

    let sessions: [ReadingSession]

    private let weeksToShow = 12
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private var heatmapData: [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)

        // Build session duration by day
        var durationByDay: [Date: TimeInterval] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)
            durationByDay[day, default: 0] += session.duration
        }

        // Generate 12 weeks of days (Mon–Sun), oldest first
        // Find the Monday that starts the oldest week
        let totalDays = weeksToShow * 7
        guard let startDay = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }

        // Align startDay to Monday
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)
        components.weekday = 2  // Monday
        guard let mondayStart = calendar.date(from: components) else { return [] }

        var days: [HeatmapDay] = []
        for offset in 0..<(weeksToShow * 7) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: mondayStart) else { continue }
            if date > today { break }
            let weekIndex = offset / 7
            let dayOfWeek = offset % 7  // 0 = Monday
            let duration = durationByDay[calendar.startOfDay(for: date)] ?? 0
            days.append(HeatmapDay(
                date: date,
                weekIndex: weekIndex,
                dayOfWeek: dayOfWeek,
                totalDuration: duration
            ))
        }
        return days
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: return AppTheme.cardBackground
        case 1: return AppTheme.primary.opacity(0.2)
        case 2: return AppTheme.primary.opacity(0.4)
        case 3: return AppTheme.primary.opacity(0.7)
        default: return AppTheme.primary
        }
    }

    private var weekLabels: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let totalDays = weeksToShow * 7
        guard let startDay = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)
        components.weekday = 2
        guard let mondayStart = calendar.date(from: components) else { return [] }

        return (0..<weeksToShow).map { weekIdx in
            guard let date = calendar.date(byAdding: .day, value: weekIdx * 7, to: mondayStart) else {
                return ""
            }
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            if day <= 7 {
                return "\(month)月"
            }
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels
                VStack(alignment: .trailing, spacing: cellSpacing) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 14, height: cellSize)
                    }
                }

                // Grid
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Month labels row
                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(weekLabels.enumerated()), id: \.offset) { idx, label in
                                Text(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: cellSize, alignment: .leading)
                            }
                        }

                        // Cells grid: columns = weeks, rows = days
                        let byWeek = Dictionary(grouping: heatmapData, by: \.weekIndex)
                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(0..<weeksToShow, id: \.self) { weekIdx in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayIdx in
                                        let day = byWeek[weekIdx]?.first(where: { $0.dayOfWeek == dayIdx })
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(color(for: day?.intensityLevel ?? 0))
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: level))
                        .frame(width: 11, height: 11)
                }
                Text("多")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

#Preview {
    CalendarHeatmapView(sessions: [])
        .padding()
}
