import Foundation

// MARK: - PresetModel

struct PresetModel: Identifiable, Equatable {
    let id: String
    let name: String
}

// MARK: - PresetProvider

struct PresetProvider: Identifiable, Equatable {
    let id: String
    let name: String
    let baseURL: String
    let models: [PresetModel]
    let supportsModelDiscovery: Bool

    init(
        id: String,
        name: String,
        baseURL: String,
        models: [PresetModel],
        supportsModelDiscovery: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.models = models
        self.supportsModelDiscovery = supportsModelDiscovery
    }
}
