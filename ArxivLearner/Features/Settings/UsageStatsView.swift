import SwiftUI
import SwiftData
import Charts

// MARK: - UsageStatsView

/// Displays token-usage statistics in three tabs:
///   1. 按模型 — per-model totals
///   2. 按场景 — bar chart by request type
///   3. 时间趋势 — line chart of daily usage over the last 30 days
///
/// Also surfaces a monthly budget tracker with colour-coded warnings.
struct UsageStatsView: View {

    // MARK: SwiftData

    @Query(sort: \UsageRecord.date, order: .reverse)
    private var allRecords: [UsageRecord]

    // MARK: Budget

    @AppStorage("monthly_budget") private var monthlyBudget: Double = 0

    // MARK: State

    @State private var selectedTab = 0
    @State private var showBudgetEditor = false
    @State private var budgetInput: String = ""

    // MARK: Computed helpers

    private var currentMonthRecords: [UsageRecord] {
        let calendar = Calendar.current
        let now = Date.now
        return allRecords.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    private var currentMonthCost: Double {
        currentMonthRecords.reduce(0) { $0 + $1.estimatedCost }
    }

    private var budgetFraction: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(currentMonthCost / monthlyBudget, 1.0)
    }

    private var budgetWarningLevel: BudgetWarningLevel {
        guard monthlyBudget > 0 else { return .none }
        let fraction = currentMonthCost / monthlyBudget
        if fraction >= 1.0 { return .exceeded }
        if fraction >= 0.8 { return .approaching }
        return .none
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                budgetBanner

                Picker("统计维度", selection: $selectedTab) {
                    Text("按模型").tag(0)
                    Text("按场景").tag(1)
                    Text("时间趋势").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(AppTheme.cardPadding)

                TabView(selection: $selectedTab) {
                    byModelTab.tag(0)
                    bySceneTab.tag(1)
                    trendTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("使用统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        budgetInput = monthlyBudget > 0
                            ? String(format: "%.2f", monthlyBudget)
                            : ""
                        showBudgetEditor = true
                    } label: {
                        Label("设置预算", systemImage: "dollarsign.circle")
                    }
                    .foregroundStyle(AppTheme.primary)
                }
            }
            .sheet(isPresented: $showBudgetEditor) {
                budgetEditorSheet
            }
        }
    }

    // MARK: - Budget Banner

    @ViewBuilder
    private var budgetBanner: some View {
        if monthlyBudget > 0 {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("本月预算")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(String(format: "$%.4f / $%.2f", currentMonthCost, monthlyBudget))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(budgetWarningLevel.color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.cardBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(budgetWarningLevel.color)
                            .frame(width: geo.size.width * budgetFraction, height: 8)
                            .animation(.easeInOut, value: budgetFraction)
                    }
                }
                .frame(height: 8)

                if budgetWarningLevel != .none {
                    Text(budgetWarningLevel.message)
                        .font(.caption)
                        .foregroundStyle(budgetWarningLevel.color)
                }
            }
            .padding(AppTheme.cardPadding)
            .background(budgetWarningLevel.color.opacity(0.07))
        }
    }

    // MARK: - Tab: By Model

    private var byModelTab: some View {
        List {
            let grouped = Dictionary(grouping: allRecords, by: \.modelId)
            let summaries = grouped.map { id, records -> ModelSummary in
                ModelSummary(
                    modelId: id,
                    modelName: records.first?.modelName ?? id,
                    providerName: records.first?.providerName ?? "",
                    totalInputTokens: records.reduce(0) { $0 + $1.inputTokens },
                    totalOutputTokens: records.reduce(0) { $0 + $1.outputTokens },
                    totalCost: records.reduce(0) { $0 + $1.estimatedCost }
                )
            }
            .sorted { $0.totalCost > $1.totalCost }

            if summaries.isEmpty {
                ContentUnavailableView(
                    "暂无数据",
                    systemImage: "chart.bar",
                    description: Text("使用 LLM 功能后将在此显示统计")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(summaries) { summary in
                    modelRow(summary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func modelRow(_ summary: ModelSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.modelName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(summary.providerName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(String(format: "$%.4f", summary.totalCost))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.primary)
            }
            HStack(spacing: 16) {
                Label("\(summary.totalInputTokens) 输入", systemImage: "arrow.up.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Label("\(summary.totalOutputTokens) 输出", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Label("\(summary.totalInputTokens + summary.totalOutputTokens) 合计",
                      systemImage: "sum")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Tab: By Scene

    private var bySceneTab: some View {
        let grouped = Dictionary(grouping: allRecords, by: \.requestTypeRawValue)
        let data: [SceneData] = grouped.map { raw, records in
            SceneData(
                type: RequestType(rawValue: raw) ?? .insightGeneration,
                count: records.count,
                totalTokens: records.reduce(0) { $0 + $1.totalTokens }
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if data.isEmpty {
                    ContentUnavailableView(
                        "暂无数据",
                        systemImage: "chart.bar.xaxis",
                        description: Text("使用 LLM 功能后将在此显示统计")
                    )
                    .padding(.top, 40)
                } else {
                    Text("各场景 Token 用量")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, AppTheme.cardPadding)

                    Chart(data) { item in
                        BarMark(
                            x: .value("场景", item.type.displayName),
                            y: .value("Token", item.totalTokens)
                        )
                        .foregroundStyle(AppTheme.primary.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel(orientation: .verticalReversed)
                        }
                    }
                    .frame(height: 260)
                    .padding(.horizontal, AppTheme.cardPadding)

                    Divider()

                    VStack(spacing: 0) {
                        ForEach(data) { item in
                            HStack {
                                Text(item.type.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.totalTokens) tokens")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(item.count) 次请求")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, AppTheme.cardPadding)
                            .padding(.vertical, 10)
                            Divider().padding(.leading, AppTheme.cardPadding)
                        }
                    }
                }
            }
            .padding(.vertical, AppTheme.cardPadding)
        }
    }

    // MARK: - Tab: Time Trend

    private var trendTab: some View {
        let dailyData = buildDailyData()
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if dailyData.allSatisfy({ $0.totalTokens == 0 }) {
                    ContentUnavailableView(
                        "暂无数据",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("最近 30 天无使用记录")
                    )
                    .padding(.top, 40)
                } else {
                    Text("每日 Token 用量（近 30 天）")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, AppTheme.cardPadding)

                    Chart(dailyData) { day in
                        LineMark(
                            x: .value("日期", day.date, unit: .day),
                            y: .value("Token", day.totalTokens)
                        )
                        .foregroundStyle(AppTheme.primary.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("日期", day.date, unit: .day),
                            y: .value("Token", day.totalTokens)
                        )
                        .foregroundStyle(AppTheme.primary.opacity(0.15).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    }
                    .frame(height: 220)
                    .padding(.horizontal, AppTheme.cardPadding)

                    Divider()

                    // Cost trend chart
                    Text("每日费用估算（近 30 天）")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, AppTheme.cardPadding)
                        .padding(.top, 8)

                    Chart(dailyData) { day in
                        BarMark(
                            x: .value("日期", day.date, unit: .day),
                            y: .value("费用 ($)", day.totalCost)
                        )
                        .foregroundStyle(AppTheme.secondary.gradient)
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "$%.4f", v))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, AppTheme.cardPadding)
                }
            }
            .padding(.vertical, AppTheme.cardPadding)
        }
    }

    // MARK: - Budget Editor Sheet

    private var budgetEditorSheet: some View {
        NavigationStack {
            Form {
                Section("每月预算 (USD)") {
                    TextField("0.00", text: $budgetInput)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text("当预算使用达到 80% 时显示黄色警告，达到 100% 时显示红色警告。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .navigationTitle("预算设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let value = Double(budgetInput) {
                            monthlyBudget = max(0, value)
                        } else if budgetInput.isEmpty {
                            monthlyBudget = 0
                        }
                        showBudgetEditor = false
                    }
                    .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showBudgetEditor = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Data Builders

    private func buildDailyData() -> [DailyData] {
        let calendar = Calendar.current
        let today = Date.now
        return (0..<30).reversed().map { offset -> DailyData in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return DailyData(date: today, totalTokens: 0, totalCost: 0)
            }
            let dayRecords = allRecords.filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            return DailyData(
                date: date,
                totalTokens: dayRecords.reduce(0) { $0 + $1.totalTokens },
                totalCost: dayRecords.reduce(0) { $0 + $1.estimatedCost }
            )
        }
    }
}

// MARK: - Supporting Types

private struct ModelSummary: Identifiable {
    let modelId: String
    let modelName: String
    let providerName: String
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCost: Double

    var id: String { modelId }
}

private struct SceneData: Identifiable {
    let type: RequestType
    let count: Int
    let totalTokens: Int

    var id: String { type.rawValue }
}

private struct DailyData: Identifiable {
    let date: Date
    let totalTokens: Int
    let totalCost: Double

    var id: Date { date }
}

private enum BudgetWarningLevel: Equatable {
    case none
    case approaching   // >= 80 %
    case exceeded      // >= 100 %

    var color: Color {
        switch self {
        case .none:       return AppTheme.primary
        case .approaching: return .yellow
        case .exceeded:   return .red
        }
    }

    var message: String {
        switch self {
        case .none:       return ""
        case .approaching: return "已使用 80% 预算，请注意用量"
        case .exceeded:   return "本月预算已超出！"
        }
    }
}

// MARK: - Preview

#Preview {
    UsageStatsView()
        .modelContainer(for: [UsageRecord.self], inMemory: true)
}
