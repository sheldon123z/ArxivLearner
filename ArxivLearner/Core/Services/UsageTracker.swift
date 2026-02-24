import Foundation
import SwiftData

// MARK: - UsageTracker

/// A lightweight helper that creates and persists a `UsageRecord` in the
/// SwiftData model context.
///
/// Call `UsageTracker.record(...)` immediately after every LLM API call to
/// maintain accurate usage statistics.
enum UsageTracker {

    // MARK: Public API

    /// Creates a `UsageRecord` and inserts it into the given `ModelContext`.
    ///
    /// The record is inserted synchronously; callers are responsible for
    /// ensuring this method is called on the actor that owns the context
    /// (typically `@MainActor`).
    ///
    /// - Parameters:
    ///   - modelId: The identifier of the model that handled the request.
    ///   - modelName: The human-readable model name at the time of the request.
    ///   - providerName: The human-readable provider name at the time of the request.
    ///   - inputTokens: Number of tokens in the prompt.
    ///   - outputTokens: Number of tokens in the completion.
    ///   - estimatedCost: Estimated cost in USD computed from provider pricing.
    ///   - requestType: The classification of this LLM call.
    ///   - context: The SwiftData model context used to persist the record.
    static func record(
        modelId: String,
        modelName: String,
        providerName: String,
        inputTokens: Int,
        outputTokens: Int,
        estimatedCost: Double,
        requestType: RequestType,
        context: ModelContext
    ) {
        let record = UsageRecord(
            modelId: modelId,
            modelName: modelName,
            providerName: providerName,
            date: .now,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            estimatedCost: estimatedCost,
            requestType: requestType
        )
        context.insert(record)
        // Best-effort save; errors are non-fatal for usage tracking.
        try? context.save()
    }
}
