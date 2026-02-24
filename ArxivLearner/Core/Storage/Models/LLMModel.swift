import Foundation
import SwiftData

// MARK: - ModelCapabilities

/// Describes the feature set supported by a specific LLM model.
/// Serialised as JSON and stored in `LLMModel.capabilitiesData`.
struct ModelCapabilities: Codable, Equatable {
    var textInput: Bool = true
    var textOutput: Bool = true
    var imageInput: Bool = false
    var imageOutput: Bool = false
    var pdfInput: Bool = false
    var functionCalling: Bool = false
    var streaming: Bool = true
    var jsonMode: Bool = false
    var reasoning: Bool = false
}

// MARK: - LLMModel

/// A SwiftData model representing a single AI model offered by an `LLMProvider`.
///
/// Pricing fields use US-dollar cost per million tokens (M-token), consistent with
/// how most provider dashboards and APIs report pricing.
@Model
final class LLMModel {

    // MARK: Stored Properties

    @Attribute(.unique) var id: UUID
    /// Back-reference to the owning provider. Nullable to allow orphaned records during migration.
    var provider: LLMProvider?
    /// The model identifier string used in API requests (e.g. "gpt-4o", "claude-sonnet-4-20250514").
    var modelId: String
    var displayName: String
    var contextWindow: Int
    var maxOutputTokens: Int?
    /// JSON-encoded `ModelCapabilities`. Use the computed `capabilities` property for typed access.
    var capabilitiesData: Data?
    /// Input cost in USD per million tokens (nil if pricing is unknown).
    var inputPricePerMToken: Double?
    /// Output cost in USD per million tokens (nil if pricing is unknown).
    var outputPricePerMToken: Double?
    var isDefault: Bool
    var isEnabled: Bool

    // MARK: Computed Typed Access

    /// Decoded `ModelCapabilities` from `capabilitiesData`.
    /// Setting this property re-encodes and stores the updated value.
    var capabilities: ModelCapabilities {
        get {
            guard let data = capabilitiesData,
                  let decoded = try? JSONDecoder().decode(ModelCapabilities.self, from: data)
            else {
                return ModelCapabilities()
            }
            return decoded
        }
        set {
            capabilitiesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        provider: LLMProvider? = nil,
        modelId: String = "",
        displayName: String = "",
        contextWindow: Int = 128_000,
        maxOutputTokens: Int? = nil,
        capabilities: ModelCapabilities = ModelCapabilities(),
        inputPricePerMToken: Double? = nil,
        outputPricePerMToken: Double? = nil,
        isDefault: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.provider = provider
        self.modelId = modelId
        self.displayName = displayName
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.capabilitiesData = try? JSONEncoder().encode(capabilities)
        self.inputPricePerMToken = inputPricePerMToken
        self.outputPricePerMToken = outputPricePerMToken
        self.isDefault = isDefault
        self.isEnabled = isEnabled
    }
}
