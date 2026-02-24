import Foundation
import SwiftData

// MARK: - UsageRecord

/// A SwiftData model that captures token consumption and cost for a single LLM API call.
///
/// Provider and model information is denormalised (stored as plain strings) so that
/// usage history remains readable even after a provider or model is later deleted or
/// renamed.
@Model
final class UsageRecord {

    // MARK: Stored Properties

    var id: UUID
    /// Identifier of the model that handled the request (mirrors `LLMModel.modelId`).
    var modelId: String
    /// Display name of the model at the time of the request.
    var modelName: String
    /// Display name of the provider at the time of the request.
    var providerName: String
    var date: Date
    var inputTokens: Int
    var outputTokens: Int
    /// Estimated cost in USD computed from provider pricing at the time of the request.
    var estimatedCost: Double
    /// Raw value of `RequestType`. Use the computed `type` property for typed access.
    var requestTypeRawValue: String

    // MARK: Computed Typed Access

    /// Typed access to the request type. Falls back to `.insightGeneration` for unknown raw values.
    var type: RequestType {
        get { RequestType(rawValue: requestTypeRawValue) ?? .insightGeneration }
        set { requestTypeRawValue = newValue.rawValue }
    }

    /// Total tokens consumed by this request.
    var totalTokens: Int { inputTokens + outputTokens }

    // MARK: Init

    init(
        id: UUID = UUID(),
        modelId: String = "",
        modelName: String = "",
        providerName: String = "",
        date: Date = .now,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        estimatedCost: Double = 0,
        requestType: RequestType = .insightGeneration
    ) {
        self.id = id
        self.modelId = modelId
        self.modelName = modelName
        self.providerName = providerName
        self.date = date
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCost = estimatedCost
        self.requestTypeRawValue = requestType.rawValue
    }
}
