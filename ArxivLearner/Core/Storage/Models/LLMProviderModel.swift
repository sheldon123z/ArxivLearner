import Foundation

// MARK: - LLMProviderConfig
// A plain Codable struct (not a SwiftData model) used to configure LLM providers.
// Stored via UserDefaults or a JSON file rather than the SwiftData store for MVP simplicity.

struct LLMProviderConfig: Codable, Equatable {
    var name: String
    var baseURL: String
    var apiKey: String
    var modelId: String

    init(
        name: String = "",
        baseURL: String = "",
        apiKey: String = "",
        modelId: String = ""
    ) {
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelId = modelId
    }
}
