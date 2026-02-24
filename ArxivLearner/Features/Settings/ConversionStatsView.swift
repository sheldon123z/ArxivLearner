import SwiftUI

// MARK: - ConversionStatsView

struct ConversionStatsView: View {
    @State private var monthlyPages: Int = 0
    @State private var totalPages: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Section("本月统计") {
                    HStack {
                        Label("已转换页数", systemImage: "doc.text")
                        Spacer()
                        Text("\(monthlyPages) 页")
                            .foregroundStyle(AppTheme.textSecondary)
                            .fontWeight(.semibold)
                    }
                }

                Section("历史累计") {
                    HStack {
                        Label("总转换页数", systemImage: "books.vertical")
                        Spacer()
                        Text("\(totalPages) 页")
                            .foregroundStyle(AppTheme.textSecondary)
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        resetStats()
                    } label: {
                        HStack {
                            Spacer()
                            Text("重置统计数据")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("转换统计")
            .onAppear { loadStats() }
        }
    }

    private func loadStats() {
        monthlyPages = ConversionStats.monthlyPages
        totalPages = ConversionStats.totalPages
    }

    private func resetStats() {
        UserDefaults.standard.set(0, forKey: "conversion_stats_monthly_pages")
        UserDefaults.standard.set(0, forKey: "conversion_stats_total_pages")
        UserDefaults.standard.set(0, forKey: "conversion_stats_month")
        UserDefaults.standard.set(0, forKey: "conversion_stats_year")
        loadStats()
    }
}

// MARK: - Preview

#Preview {
    ConversionStatsView()
}
