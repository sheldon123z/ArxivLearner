import Foundation

// MARK: - PromptVariableEngine

/// Resolves template variable placeholders in prompt strings by substituting
/// values derived from a `Paper` model and optional contextual data.
///
/// Supported variables:
/// - `{{title}}`         – paper title
/// - `{{abstract}}`      – paper abstract text
/// - `{{authors}}`       – comma-joined author list
/// - `{{categories}}`    – comma-joined arXiv category list
/// - `{{full_text}}`     – converted Markdown content, or a fallback notice
/// - `{{selected_text}}` – caller-supplied selected text, or empty string
enum PromptVariableEngine {

    // MARK: - Public API

    /// Replaces all recognised template variables in `template` with values
    /// drawn from `paper` and the optional `selectedText` parameter.
    ///
    /// - Parameters:
    ///   - template:     A prompt string that may contain `{{variable}}` placeholders.
    ///   - paper:        The `Paper` whose data will populate the variables.
    ///   - selectedText: Text the user has highlighted in the reader, if any.
    /// - Returns: The resolved prompt string with all placeholders replaced.
    static func resolve(template: String, paper: Paper, selectedText: String? = nil) -> String {
        var result = template

        // {{title}}
        result = result.replacingOccurrences(
            of: "{{title}}",
            with: titleValue(for: paper)
        )

        // {{abstract}}
        result = result.replacingOccurrences(
            of: "{{abstract}}",
            with: abstractValue(for: paper)
        )

        // {{authors}}
        result = result.replacingOccurrences(
            of: "{{authors}}",
            with: authorsValue(for: paper)
        )

        // {{categories}}
        result = result.replacingOccurrences(
            of: "{{categories}}",
            with: categoriesValue(for: paper)
        )

        // {{full_text}}
        result = result.replacingOccurrences(
            of: "{{full_text}}",
            with: fullTextValue(for: paper)
        )

        // {{selected_text}}
        result = result.replacingOccurrences(
            of: "{{selected_text}}",
            with: selectedTextValue(selectedText)
        )

        return result
    }

    // MARK: - Private Resolvers

    private static func titleValue(for paper: Paper) -> String {
        let title = paper.title.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "(标题不可用)" : title
    }

    private static func abstractValue(for paper: Paper) -> String {
        let abstract = paper.abstractText.trimmingCharacters(in: .whitespaces)
        return abstract.isEmpty ? "(摘要不可用)" : abstract
    }

    private static func authorsValue(for paper: Paper) -> String {
        let authors = paper.authors.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return authors.isEmpty ? "(作者信息不可用)" : authors.joined(separator: ", ")
    }

    private static func categoriesValue(for paper: Paper) -> String {
        let categories = paper.categories.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return categories.isEmpty ? "(分类信息不可用)" : categories.joined(separator: ", ")
    }

    private static func fullTextValue(for paper: Paper) -> String {
        if let markdown = paper.markdownContent, !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return markdown
        }
        return "(全文内容不可用)"
    }

    private static func selectedTextValue(_ selectedText: String?) -> String {
        guard let text = selectedText else { return "" }
        return text
    }
}
