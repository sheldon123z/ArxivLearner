import XCTest
import SwiftData
@testable import ArxivLearner

// MARK: - UsageRecordTests

final class UsageRecordTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an in-memory ModelContainer with all SwiftData models required by the schema.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Paper.self,
            ChatMessage.self,
            LLMProvider.self,
            LLMModel.self,
            PromptTemplate.self,
            UsageRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Returns a fixed reference date used across date-range tests.
    private var referenceDate: Date {
        // 2024-06-01 00:00:00 UTC
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Creation Tests

    func testUsageRecordCreationWithAllFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let fixedId = UUID()
        let fixedDate = referenceDate

        let record = UsageRecord(
            id: fixedId,
            modelId: "gpt-4o",
            modelName: "GPT-4o",
            providerName: "OpenAI",
            date: fixedDate,
            inputTokens: 500,
            outputTokens: 300,
            estimatedCost: 0.012,
            requestType: .paperChat
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "gpt-4o" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        let fetched = try XCTUnwrap(results.first)
        XCTAssertEqual(fetched.id, fixedId)
        XCTAssertEqual(fetched.modelId, "gpt-4o")
        XCTAssertEqual(fetched.modelName, "GPT-4o")
        XCTAssertEqual(fetched.providerName, "OpenAI")
        XCTAssertEqual(fetched.date, fixedDate)
        XCTAssertEqual(fetched.inputTokens, 500)
        XCTAssertEqual(fetched.outputTokens, 300)
        XCTAssertEqual(fetched.estimatedCost, 0.012, accuracy: 1e-9)
        XCTAssertEqual(fetched.requestTypeRawValue, RequestType.paperChat.rawValue)
    }

    func testUsageRecordDefaultValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = UsageRecord()
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>()
        let results = try context.fetch(descriptor)
        let fetched = try XCTUnwrap(results.first)

        XCTAssertEqual(fetched.modelId, "")
        XCTAssertEqual(fetched.modelName, "")
        XCTAssertEqual(fetched.providerName, "")
        XCTAssertEqual(fetched.inputTokens, 0)
        XCTAssertEqual(fetched.outputTokens, 0)
        XCTAssertEqual(fetched.estimatedCost, 0.0, accuracy: 1e-9)
        XCTAssertEqual(fetched.requestTypeRawValue, RequestType.insightGeneration.rawValue)
    }

    // MARK: - Computed Property: totalTokens

    func testTotalTokensIsInputPlusOutput() {
        let record = UsageRecord(inputTokens: 1_200, outputTokens: 800)
        XCTAssertEqual(record.totalTokens, 2_000)
    }

    func testTotalTokensWhenBothZero() {
        let record = UsageRecord()
        XCTAssertEqual(record.totalTokens, 0)
    }

    func testTotalTokensWithLargeValues() {
        let record = UsageRecord(inputTokens: 128_000, outputTokens: 32_000)
        XCTAssertEqual(record.totalTokens, 160_000)
    }

    // MARK: - Computed Property: type (RequestType getter/setter)

    func testTypeGetterReturnsCorrectRequestType() {
        for requestType in RequestType.allCases {
            let record = UsageRecord(requestType: requestType)
            XCTAssertEqual(record.type, requestType,
                "type getter should return \(requestType) when requestTypeRawValue is '\(requestType.rawValue)'")
        }
    }

    func testTypeSetterUpdatesRawValue() {
        let record = UsageRecord(requestType: .insightGeneration)
        XCTAssertEqual(record.requestTypeRawValue, "insightGeneration")

        record.type = .translation
        XCTAssertEqual(record.requestTypeRawValue, "translation")

        record.type = .formulaAnalysis
        XCTAssertEqual(record.requestTypeRawValue, "formulaAnalysis")
    }

    func testTypeGetterFallsBackToInsightGenerationForUnknownRawValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = UsageRecord(requestType: .insightGeneration)
        context.insert(record)
        try context.save()

        // Directly mutate the raw value to something unknown
        let descriptor = FetchDescriptor<UsageRecord>()
        let fetched = try XCTUnwrap(try context.fetch(descriptor).first)
        fetched.requestTypeRawValue = "unknownFutureCase"
        try context.save()

        XCTAssertEqual(fetched.type, .insightGeneration,
            "type getter should fall back to .insightGeneration for unrecognised raw values")
    }

    func testTypeRoundTripThroughSwiftData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = UsageRecord(requestType: .codeExplanation)
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>()
        let fetched = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(fetched.type, .codeExplanation)

        fetched.type = .figureAnalysis
        try context.save()

        let fetched2 = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(fetched2.type, .figureAnalysis)
        XCTAssertEqual(fetched2.requestTypeRawValue, "figureAnalysis")
    }

    // MARK: - SwiftData Fetch by modelId

    func testFetchByModelId() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let records = [
            UsageRecord(modelId: "gpt-4o", inputTokens: 100, outputTokens: 50),
            UsageRecord(modelId: "gpt-4o", inputTokens: 200, outputTokens: 80),
            UsageRecord(modelId: "claude-3-opus", inputTokens: 300, outputTokens: 150)
        ]
        records.forEach { context.insert($0) }
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "gpt-4o" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.modelId == "gpt-4o" })
    }

    func testFetchByModelIdReturnsEmptyWhenNoMatch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let record = UsageRecord(modelId: "gpt-4o")
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "nonexistent-model" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 0)
    }

    // MARK: - SwiftData Fetch by Date Range

    func testFetchByDateRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let base = referenceDate
        let oneDayInSeconds: TimeInterval = 86_400

        // Three records: day 0, day 1, day 5
        let r0 = UsageRecord(modelId: "m1", date: base)
        let r1 = UsageRecord(modelId: "m2", date: base.addingTimeInterval(oneDayInSeconds))
        let r5 = UsageRecord(modelId: "m3", date: base.addingTimeInterval(5 * oneDayInSeconds))

        [r0, r1, r5].forEach { context.insert($0) }
        try context.save()

        // Query for records between day 0 (inclusive) and day 2 (exclusive)
        let rangeStart = base
        let rangeEnd = base.addingTimeInterval(2 * oneDayInSeconds)

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.date >= rangeStart && $0.date < rangeEnd }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.date >= rangeStart && $0.date < rangeEnd })
    }

    func testFetchByDateRangeExcludesOutOfBoundRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let base = referenceDate
        let oneDayInSeconds: TimeInterval = 86_400

        let early = UsageRecord(modelId: "early", date: base.addingTimeInterval(-oneDayInSeconds))
        let inside = UsageRecord(modelId: "inside", date: base)
        let late = UsageRecord(modelId: "late", date: base.addingTimeInterval(7 * oneDayInSeconds))

        [early, inside, late].forEach { context.insert($0) }
        try context.save()

        let rangeStart = base
        let rangeEnd = base.addingTimeInterval(3 * oneDayInSeconds)

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.date >= rangeStart && $0.date < rangeEnd }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.modelId, "inside")
    }

    // MARK: - SwiftData Fetch by RequestType

    func testFetchByRequestTypeRawValue() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let r1 = UsageRecord(modelId: "m1", requestType: .translation)
        let r2 = UsageRecord(modelId: "m2", requestType: .translation)
        let r3 = UsageRecord(modelId: "m3", requestType: .summary)

        [r1, r2, r3].forEach { context.insert($0) }
        try context.save()

        let targetRaw = RequestType.translation.rawValue
        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.requestTypeRawValue == targetRaw }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.requestTypeRawValue == targetRaw })
    }

    func testFetchByEachRequestType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Insert one record per request type
        for requestType in RequestType.allCases {
            let record = UsageRecord(
                modelId: "model-\(requestType.rawValue)",
                requestType: requestType
            )
            context.insert(record)
        }
        try context.save()

        for requestType in RequestType.allCases {
            let raw = requestType.rawValue
            let descriptor = FetchDescriptor<UsageRecord>(
                predicate: #Predicate { $0.requestTypeRawValue == raw }
            )
            let results = try context.fetch(descriptor)
            XCTAssertEqual(results.count, 1,
                "Expected exactly 1 record for requestType '\(requestType.rawValue)'")
        }
    }

    // MARK: - Cost Aggregation

    func testCostAggregationSumAcrossRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let costs = [0.001, 0.005, 0.0023, 0.010]
        let expectedTotal = costs.reduce(0, +)

        costs.forEach { cost in
            context.insert(UsageRecord(modelId: "gpt-4o", estimatedCost: cost))
        }
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "gpt-4o" }
        )
        let results = try context.fetch(descriptor)

        let actualTotal = results.reduce(0.0) { $0 + $1.estimatedCost }
        XCTAssertEqual(actualTotal, expectedTotal, accuracy: 1e-9)
    }

    func testCostAggregationAcrossMultipleModels() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let gptCosts = [0.01, 0.02]
        let claudeCosts = [0.005, 0.003]

        gptCosts.forEach { cost in
            context.insert(UsageRecord(modelId: "gpt-4o", estimatedCost: cost))
        }
        claudeCosts.forEach { cost in
            context.insert(UsageRecord(modelId: "claude-3-opus", estimatedCost: cost))
        }
        try context.save()

        let allDescriptor = FetchDescriptor<UsageRecord>()
        let allRecords = try context.fetch(allDescriptor)

        let grandTotal = allRecords.reduce(0.0) { $0 + $1.estimatedCost }
        let expectedGrand = (gptCosts + claudeCosts).reduce(0, +)
        XCTAssertEqual(grandTotal, expectedGrand, accuracy: 1e-9)

        let gptDescriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "gpt-4o" }
        )
        let gptTotal = try context.fetch(gptDescriptor).reduce(0.0) { $0 + $1.estimatedCost }
        XCTAssertEqual(gptTotal, gptCosts.reduce(0, +), accuracy: 1e-9)
    }

    func testTokenAggregationSumAcrossRecords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let inputValues  = [100, 200, 300]
        let outputValues = [50,  80,  120]

        for (input, output) in zip(inputValues, outputValues) {
            context.insert(UsageRecord(modelId: "gpt-4o", inputTokens: input, outputTokens: output))
        }
        try context.save()

        let descriptor = FetchDescriptor<UsageRecord>(
            predicate: #Predicate { $0.modelId == "gpt-4o" }
        )
        let results = try context.fetch(descriptor)

        let totalInput  = results.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = results.reduce(0) { $0 + $1.outputTokens }
        let totalAll    = results.reduce(0) { $0 + $1.totalTokens }

        XCTAssertEqual(totalInput,  inputValues.reduce(0, +))
        XCTAssertEqual(totalOutput, outputValues.reduce(0, +))
        XCTAssertEqual(totalAll,    totalInput + totalOutput)
    }

    // MARK: - RequestType Enum

    func testRequestTypeAllCasesCount() {
        XCTAssertEqual(RequestType.allCases.count, 8)
    }

    func testRequestTypeRawValues() {
        XCTAssertEqual(RequestType.insightGeneration.rawValue, "insightGeneration")
        XCTAssertEqual(RequestType.paperChat.rawValue,         "paperChat")
        XCTAssertEqual(RequestType.translation.rawValue,       "translation")
        XCTAssertEqual(RequestType.codeExplanation.rawValue,   "codeExplanation")
        XCTAssertEqual(RequestType.figureAnalysis.rawValue,    "figureAnalysis")
        XCTAssertEqual(RequestType.summary.rawValue,           "summary")
        XCTAssertEqual(RequestType.innovationExtract.rawValue, "innovationExtract")
        XCTAssertEqual(RequestType.formulaAnalysis.rawValue,   "formulaAnalysis")
    }

    func testRequestTypeDisplayNamesAreNonEmpty() {
        for requestType in RequestType.allCases {
            let name = requestType.displayName
            XCTAssertFalse(name.isEmpty,
                "displayName for \(requestType.rawValue) must not be empty")
        }
    }

    func testRequestTypeDisplayNamesAreChineseStrings() {
        // Every display name must contain at least one CJK Unified Ideograph (U+4E00–U+9FFF)
        let cjkRange = "\u{4E00}"..."\u{9FFF}"

        for requestType in RequestType.allCases {
            let containsCJK = requestType.displayName.unicodeScalars.contains {
                cjkRange.contains(String($0))
            }
            XCTAssertTrue(containsCJK,
                "displayName '\(requestType.displayName)' for \(requestType.rawValue) should contain Chinese characters")
        }
    }

    func testRequestTypeSpecificDisplayNames() {
        XCTAssertEqual(RequestType.insightGeneration.displayName, "核心见解")
        XCTAssertEqual(RequestType.paperChat.displayName,         "论文问答")
        XCTAssertEqual(RequestType.translation.displayName,       "全文翻译")
        XCTAssertEqual(RequestType.codeExplanation.displayName,   "代码解释")
        XCTAssertEqual(RequestType.figureAnalysis.displayName,    "图表分析")
        XCTAssertEqual(RequestType.summary.displayName,           "摘要总结")
        XCTAssertEqual(RequestType.innovationExtract.displayName, "创新点提取")
        XCTAssertEqual(RequestType.formulaAnalysis.displayName,   "公式解析")
    }

    func testRequestTypeInitFromRawValue() {
        XCTAssertEqual(RequestType(rawValue: "paperChat"),       .paperChat)
        XCTAssertEqual(RequestType(rawValue: "translation"),     .translation)
        XCTAssertNil(RequestType(rawValue: "unknownCase"),
            "Unknown raw value should produce nil, not a crash")
    }

    // MARK: - ProviderType Enum

    func testProviderTypeAllCasesCount() {
        XCTAssertEqual(ProviderType.allCases.count, 9)
    }

    func testProviderTypeRawValues() {
        XCTAssertEqual(ProviderType.openai.rawValue,       "openai")
        XCTAssertEqual(ProviderType.anthropic.rawValue,    "anthropic")
        XCTAssertEqual(ProviderType.google.rawValue,       "google")
        XCTAssertEqual(ProviderType.deepseek.rawValue,     "deepseek")
        XCTAssertEqual(ProviderType.openRouter.rawValue,   "openRouter")
        XCTAssertEqual(ProviderType.customOpenAI.rawValue, "customOpenAI")
        XCTAssertEqual(ProviderType.zhipu.rawValue,        "zhipu")
        XCTAssertEqual(ProviderType.dashscope.rawValue,    "dashscope")
        XCTAssertEqual(ProviderType.minimax.rawValue,      "minimax")
    }

    func testProviderTypeDisplayNamesAreNonEmpty() {
        for providerType in ProviderType.allCases {
            let name = providerType.displayName
            XCTAssertFalse(name.isEmpty,
                "displayName for \(providerType.rawValue) must not be empty")
        }
    }

    func testProviderTypeDisplayNamesForInternationalProviders() {
        // International providers should have standard ASCII names
        XCTAssertEqual(ProviderType.openai.displayName,     "OpenAI")
        XCTAssertEqual(ProviderType.anthropic.displayName,  "Anthropic (Claude)")
        XCTAssertEqual(ProviderType.google.displayName,     "Google (Gemini)")
        XCTAssertEqual(ProviderType.deepseek.displayName,   "DeepSeek")
        XCTAssertEqual(ProviderType.openRouter.displayName, "OpenRouter")
        XCTAssertEqual(ProviderType.minimax.displayName,    "Minimax")
    }

    func testProviderTypeDisplayNamesForChineseProviders() {
        // Chinese providers should include Chinese characters in their display names
        let cjkRange = "\u{4E00}"..."\u{9FFF}"
        let chineseProviders: [ProviderType] = [.customOpenAI, .zhipu, .dashscope]

        for provider in chineseProviders {
            let containsCJK = provider.displayName.unicodeScalars.contains {
                cjkRange.contains(String($0))
            }
            XCTAssertTrue(containsCJK,
                "displayName '\(provider.displayName)' for \(provider.rawValue) should contain Chinese characters")
        }
    }

    func testProviderTypeInitFromRawValue() {
        XCTAssertEqual(ProviderType(rawValue: "openai"),     .openai)
        XCTAssertEqual(ProviderType(rawValue: "dashscope"),  .dashscope)
        XCTAssertNil(ProviderType(rawValue: "unknownProvider"),
            "Unknown raw value should produce nil, not a crash")
    }
}
