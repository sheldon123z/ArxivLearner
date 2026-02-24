import Foundation
import SwiftData

// MARK: - DefaultPromptsLoader

/// Seeds the SwiftData store with the built-in `PromptTemplate` records defined in
/// `DefaultPrompts.json` the first time the app launches (or whenever the store
/// contains no built-in templates).
///
/// Call `loadIfNeeded(context:)` once from `ArxivLearnerApp.init` or from an
/// `.onAppear` modifier on the root view, passing the active `ModelContext`.
enum DefaultPromptsLoader {

    // MARK: - Public API

    /// Loads built-in prompts from `DefaultPrompts.json` in the main bundle and
    /// inserts them into the SwiftData store if no built-in templates are present.
    ///
    /// The check is intentionally coarse: if *any* `PromptTemplate` with
    /// `isBuiltIn == true` already exists the method returns immediately, which
    /// prevents duplicate seeding across app restarts while still allowing the
    /// caller to invoke this method unconditionally on every launch.
    ///
    /// - Parameter context: The SwiftData `ModelContext` to insert records into.
    static func loadIfNeeded(context: ModelContext) {
        guard !builtInTemplatesExist(in: context) else { return }

        guard let templates = loadFromBundle() else {
            assertionFailure("DefaultPromptsLoader: Failed to load or parse DefaultPrompts.json")
            return
        }

        for (index, dto) in templates.enumerated() {
            let template = PromptTemplate(
                name: dto.name,
                scene: PromptScene(rawValue: dto.scene) ?? .custom,
                systemPrompt: dto.systemPrompt,
                userPromptTemplate: dto.userPromptTemplate,
                responseLanguage: dto.responseLanguage,
                outputFormat: OutputFormat(rawValue: dto.outputFormat) ?? .markdown,
                temperature: dto.temperature,
                maxTokens: dto.maxTokens,
                boundModel: nil,
                isBuiltIn: true,
                sortOrder: index
            )
            context.insert(template)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("DefaultPromptsLoader: Failed to save context after seeding – \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Returns `true` when at least one `PromptTemplate` with `isBuiltIn == true`
    /// already exists in the store.
    private static func builtInTemplatesExist(in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        descriptor.fetchLimit = 1

        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    /// Reads and decodes `DefaultPrompts.json` from `Bundle.main`.
    /// Returns `nil` on any error so the caller can handle it gracefully.
    private static func loadFromBundle() -> [PromptTemplateDTO]? {
        guard let url = Bundle.main.url(forResource: "DefaultPrompts", withExtension: "json") else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode([PromptTemplateDTO].self, from: data)
    }
}

// MARK: - PromptTemplateDTO

/// A lightweight, `Decodable`-only value type that mirrors the JSON structure of
/// each entry in `DefaultPrompts.json`.  It is intentionally kept private to this
/// file to avoid polluting the module namespace.
private struct PromptTemplateDTO: Decodable {
    let name: String
    let scene: String
    let systemPrompt: String
    let userPromptTemplate: String
    let responseLanguage: String
    let outputFormat: String
    let temperature: Double
    let maxTokens: Int

    // MARK: CodingKeys

    enum CodingKeys: String, CodingKey {
        case name
        case scene
        case systemPrompt
        case userPromptTemplate
        case responseLanguage
        case outputFormat
        case temperature
        case maxTokens
    }
}
