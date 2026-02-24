import Foundation

// MARK: - LaTeXExtractor

/// Extracts LaTeX math formulas from Markdown content.
///
/// Supports two syntax forms:
/// - Display math: `$$...$$`  (block-level, parsed first to avoid false positives)
/// - Inline math:  `$...$`    (single dollar-sign delimiters)
enum LaTeXExtractor {

    // MARK: Public API

    /// Extract all LaTeX formulas from the given Markdown string.
    ///
    /// Display formulas (`$$...$$`) are extracted before inline formulas (`$...$`)
    /// so that double-dollar signs are not mis-classified as two empty inline formulas.
    ///
    /// - Parameter markdown: The source Markdown/LaTeX string.
    /// - Returns: An array of formula strings, **including** their delimiters
    ///   (e.g. `"$x^2$"` or `"$$E=mc^2$$"`), in the order they appear in the text.
    static func extract(from markdown: String) -> [String] {
        var results: [String] = []

        // Track ranges already consumed by display-math matches so the inline
        // pass does not produce duplicates.
        var displayRanges: [Range<String.Index>] = []

        // 1. Display math: $$...$$  (non-greedy, allows newlines inside)
        let displayPattern = #"\$\$[\s\S]+?\$\$"#
        if let regex = try? NSRegularExpression(pattern: displayPattern, options: []) {
            let nsRange = NSRange(markdown.startIndex..., in: markdown)
            let matches = regex.matches(in: markdown, options: [], range: nsRange)
            for match in matches {
                guard let range = Range(match.range, in: markdown) else { continue }
                displayRanges.append(range)
                results.append(String(markdown[range]))
            }
        }

        // 2. Inline math: $...$ (no dollar signs or newlines inside the body)
        let inlinePattern = #"\$[^\$\n]+?\$"#
        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) {
            let nsRange = NSRange(markdown.startIndex..., in: markdown)
            let matches = regex.matches(in: markdown, options: [], range: nsRange)
            for match in matches {
                guard let range = Range(match.range, in: markdown) else { continue }
                // Skip ranges already captured as display math.
                let overlaps = displayRanges.contains { display in
                    display.overlaps(range)
                }
                if !overlaps {
                    results.append(String(markdown[range]))
                }
            }
        }

        // Return formulas sorted by their position in the original string.
        return results.sorted { lhs, rhs in
            guard
                let lhsRange = markdown.range(of: lhs, options: .literal),
                let rhsRange = markdown.range(of: rhs, options: .literal)
            else { return false }
            return lhsRange.lowerBound < rhsRange.lowerBound
        }
    }
}
