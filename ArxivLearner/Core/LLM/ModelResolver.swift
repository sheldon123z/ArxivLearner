import Foundation
import SwiftData

// MARK: - ModelResolver

/// Resolves the best `LLMModel` for a given `PromptScene` using a three-tier
/// priority strategy:
///
/// 1. **Template-bound model** – the model explicitly pinned to the template
///    (`PromptTemplate.boundModel`).
/// 2. **Scene default** – a per-scene override stored in `UserDefaults` as a
///    `[String: String]` dictionary mapping `PromptScene.rawValue` → model UUID
///    string (`ModelResolver.sceneDefaultsKey`).
/// 3. **Global default** – the first enabled `LLMModel` whose `isDefault` flag
///    is `true` in the SwiftData store.
///
/// If none of the tiers yields a result, `nil` is returned.
enum ModelResolver {

    // MARK: - UserDefaults Key

    /// The `UserDefaults` key used to persist the scene-level model mappings.
    /// The value is stored as a `[String: String]` dictionary where each key is
    /// a `PromptScene.rawValue` and each value is the UUID string of an `LLMModel`.
    static let sceneDefaultsKey = "com.arxivlearner.sceneModelDefaults"

    // MARK: - Public API

    /// Resolves the best model for the given scene using the three-tier priority
    /// described in the type documentation.
    ///
    /// - Parameters:
    ///   - template: The `PromptTemplate` associated with the request. If `nil`,
    ///               tiers 1 and 2 are both skipped and the global default is used.
    ///   - scene:    The `PromptScene` used for the scene-level lookup (tier 2).
    ///   - context:  The SwiftData `ModelContext` used to fetch models by UUID.
    /// - Returns: The resolved `LLMModel`, or `nil` if no suitable model is found.
    static func resolve(
        for template: PromptTemplate?,
        scene: PromptScene,
        context: ModelContext
    ) -> LLMModel? {
        // Tier 1: template-bound model.
        if let bound = template?.boundModel, bound.isEnabled {
            return bound
        }

        // Tier 2: scene default stored in UserDefaults.
        if let sceneModel = sceneDefault(for: scene, context: context) {
            return sceneModel
        }

        // Tier 3: global default.
        return globalDefault(context: context)
    }

    /// Returns the global default `LLMModel` — the first enabled model whose
    /// `isDefault` flag is `true` in the SwiftData store.
    ///
    /// - Parameter context: The SwiftData `ModelContext` to query.
    /// - Returns: The global default `LLMModel`, or `nil` if none is configured.
    static func globalDefault(context: ModelContext) -> LLMModel? {
        var descriptor = FetchDescriptor<LLMModel>(
            predicate: #Predicate { $0.isDefault == true && $0.isEnabled == true }
        )
        descriptor.fetchLimit = 1

        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Scene Default Persistence

    /// Returns the model saved as the scene-level default for `scene`, if any.
    ///
    /// - Parameters:
    ///   - scene:   The scene whose override should be looked up.
    ///   - context: The SwiftData `ModelContext` used to fetch the model by UUID.
    /// - Returns: The `LLMModel` for the scene, or `nil` if no override is set or
    ///            the stored UUID no longer resolves to an enabled model.
    static func sceneDefault(for scene: PromptScene, context: ModelContext) -> LLMModel? {
        let dict = UserDefaults.standard.dictionary(forKey: sceneDefaultsKey) as? [String: String] ?? [:]
        guard let uuidString = dict[scene.rawValue],
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return fetchModel(id: uuid, context: context)
    }

    /// Persists `model` as the scene-level default for `scene` in `UserDefaults`.
    ///
    /// Pass `nil` for `model` to clear an existing scene override.
    ///
    /// - Parameters:
    ///   - model: The `LLMModel` to set as the scene default, or `nil` to clear it.
    ///   - scene: The scene whose default should be updated.
    static func setSceneDefault(_ model: LLMModel?, for scene: PromptScene) {
        var dict = UserDefaults.standard.dictionary(forKey: sceneDefaultsKey) as? [String: String] ?? [:]

        if let model {
            dict[scene.rawValue] = model.id.uuidString
        } else {
            dict.removeValue(forKey: scene.rawValue)
        }

        UserDefaults.standard.set(dict, forKey: sceneDefaultsKey)
    }

    /// Clears all scene-level model overrides from `UserDefaults`.
    static func clearAllSceneDefaults() {
        UserDefaults.standard.removeObject(forKey: sceneDefaultsKey)
    }

    // MARK: - Private Helpers

    /// Fetches an enabled `LLMModel` by its UUID from the SwiftData store.
    private static func fetchModel(id: UUID, context: ModelContext) -> LLMModel? {
        var descriptor = FetchDescriptor<LLMModel>(
            predicate: #Predicate { $0.id == id && $0.isEnabled == true }
        )
        descriptor.fetchLimit = 1

        return (try? context.fetch(descriptor))?.first
    }
}
