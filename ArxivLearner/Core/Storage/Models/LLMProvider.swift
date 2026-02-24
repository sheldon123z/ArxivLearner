import Foundation
import SwiftData

// MARK: - LLMProvider

/// A SwiftData model representing a configured LLM service provider.
///
/// API keys are NOT stored here directly. Instead, `apiKeyRef` holds the Keychain
/// key name used to retrieve the actual secret at runtime via `KeychainService`.
@Model
final class LLMProvider {

    // MARK: Stored Properties

    @Attribute(.unique) var id: UUID
    var name: String
    /// Raw value of `ProviderType`. Use the computed `type` property for typed access.
    var providerType: String
    var baseURL: String
    /// The Keychain key reference (identifier), NOT the actual API key value.
    var apiKeyRef: String
    var customHeaders: [String: String]?
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date

    // MARK: Relationships

    /// Models offered by this provider. Deleted automatically when the provider is removed.
    @Relationship(deleteRule: .cascade, inverse: \LLMModel.provider)
    var models: [LLMModel] = []

    // MARK: Computed Typed Access

    /// Typed access to the provider type. Falls back to `.customOpenAI` for unknown raw values.
    var type: ProviderType {
        get { ProviderType(rawValue: providerType) ?? .customOpenAI }
        set { providerType = newValue.rawValue }
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String = "",
        providerType: ProviderType = .customOpenAI,
        baseURL: String = "",
        apiKeyRef: String = "",
        customHeaders: [String: String]? = nil,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType.rawValue
        self.baseURL = baseURL
        self.apiKeyRef = apiKeyRef
        self.customHeaders = customHeaders
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
