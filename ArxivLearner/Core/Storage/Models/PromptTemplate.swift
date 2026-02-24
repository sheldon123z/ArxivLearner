import Foundation
import SwiftData

// MARK: - PromptTemplate

/// A SwiftData model representing a reusable LLM prompt configuration.
///
/// Built-in templates (`isBuiltIn == true`) are seeded from `DefaultPrompts.json` at
/// first launch and should not be deleted by the user. Custom templates can be created,
/// edited, and removed freely.
///
/// Supported template variables in `userPromptTemplate`:
/// - `{{title}}` – paper title
/// - `{{authors}}` – comma-joined author list
/// - `{{categories}}` – comma-joined arXiv categories
/// - `{{abstract}}` – paper abstract text
/// - `{{full_text}}` – converted Markdown full text (may be absent)
@Model
final class PromptTemplate {

    // MARK: Stored Properties

    @Attribute(.unique) var id: UUID
    var name: String
    /// Raw value of `PromptScene`. Use the computed `scene` property for typed access.
    var sceneRawValue: String
    var systemPrompt: String
    var userPromptTemplate: String
    /// BCP 47 language tag for the desired response language (e.g. "zh-CN", "en-US").
    var responseLanguage: String
    /// Raw value of `OutputFormat`. Use the computed `format` property for typed access.
    var outputFormatRawValue: String
    /// Sampling temperature (0.0 – 2.0). Lower values produce more deterministic output.
    var temperature: Double
    /// Upper bound on the number of tokens the model may generate in its response.
    var maxTokens: Int
    /// Optional pinned model for this template. If nil, the active provider's default is used.
    var boundModel: LLMModel?
    var isBuiltIn: Bool
    var sortOrder: Int

    // MARK: Computed Typed Access

    /// Typed access to the prompt scene. Falls back to `.custom` for unknown raw values.
    var scene: PromptScene {
        get { PromptScene(rawValue: sceneRawValue) ?? .custom }
        set { sceneRawValue = newValue.rawValue }
    }

    /// Typed access to the output format. Falls back to `.markdown` for unknown raw values.
    var format: OutputFormat {
        get { OutputFormat(rawValue: outputFormatRawValue) ?? .markdown }
        set { outputFormatRawValue = newValue.rawValue }
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String = "",
        scene: PromptScene = .custom,
        systemPrompt: String = "",
        userPromptTemplate: String = "",
        responseLanguage: String = "zh-CN",
        outputFormat: OutputFormat = .markdown,
        temperature: Double = 0.7,
        maxTokens: Int = 2000,
        boundModel: LLMModel? = nil,
        isBuiltIn: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sceneRawValue = scene.rawValue
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
        self.responseLanguage = responseLanguage
        self.outputFormatRawValue = outputFormat.rawValue
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.boundModel = boundModel
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}
