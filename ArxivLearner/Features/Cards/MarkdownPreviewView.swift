import SwiftUI

// MARK: - MarkdownToken

/// Parsed token from a Markdown string.
private enum MarkdownToken {
    case h1(String)
    case h2(String)
    case h3(String)
    case codeBlock(String)         // fenced code: ```...```
    case latexDisplay(String)      // display math: $$...$$
    case bullet(NSAttributedString) // - item (may contain inline formatting)
    case paragraph(NSAttributedString)
    case horizontalRule
}

// MARK: - MarkdownPreviewView

/// Renders a Markdown string with basic formatting support:
///
/// - Headers: `#`, `##`, `###`
/// - Bold: `**text**` / `__text__`
/// - Italic: `*text*` / `_text_`
/// - Inline code: `` `code` ``
/// - Fenced code blocks: ```` ``` ````
/// - Inline LaTeX: `$formula$` — displayed in monospace
/// - Display LaTeX: `$$formula$$` — displayed in a styled block
/// - Unordered list items: `- item`
/// - Horizontal rules: `---`
struct MarkdownPreviewView: View {

    // MARK: Input

    let markdownContent: String

    // MARK: State

    @State private var tokens: [MarkdownToken] = []

    // MARK: Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    tokenView(for: token)
                }
            }
            .padding(AppTheme.cardPadding)
        }
        .onAppear { tokens = MarkdownParser.parse(markdownContent) }
        .onChange(of: markdownContent) { _, new in tokens = MarkdownParser.parse(new) }
    }

    // MARK: Token Rendering

    @ViewBuilder
    private func tokenView(for token: MarkdownToken) -> some View {
        switch token {

        case .h1(let text):
            Text(text)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 8)

        case .h2(let text):
            Text(text)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 6)

        case .h3(let text):
            Text(text)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 4)

        case .codeBlock(let code):
            codeBlockView(code)

        case .latexDisplay(let formula):
            latexDisplayView(formula)

        case .bullet(let attributed):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(AppTheme.primary)
                Text(AttributedString(attributed))
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
            }

        case .paragraph(let attributed):
            Text(AttributedString(attributed))
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: Subviews

    private func codeBlockView(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(UIColor.label))
                .padding(10)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func latexDisplayView(_ formula: String) -> some View {
        Text(formula)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(AppTheme.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - MarkdownParser

/// Converts a Markdown string into an array of `MarkdownToken` values.
private enum MarkdownParser {

    static func parse(_ markdown: String) -> [MarkdownToken] {
        var tokens: [MarkdownToken] = []
        var lines = markdown.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code block
            if line.hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                tokens.append(.codeBlock(codeLines.joined(separator: "\n")))
                index += 1
                continue
            }

            // Display LaTeX block $$...$$ (may be multi-line)
            if line.trimmingCharacters(in: .whitespaces) == "$$" {
                var latexLines: [String] = []
                index += 1
                while index < lines.count &&
                      lines[index].trimmingCharacters(in: .whitespaces) != "$$" {
                    latexLines.append(lines[index])
                    index += 1
                }
                tokens.append(.latexDisplay(latexLines.joined(separator: "\n")))
                index += 1
                continue
            }

            // Inline display math $$ on single line
            if line.hasPrefix("$$") && line.hasSuffix("$$") && line.count > 4 {
                let inner = String(line.dropFirst(2).dropLast(2))
                tokens.append(.latexDisplay(inner))
                index += 1
                continue
            }

            // Horizontal rule
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                tokens.append(.horizontalRule)
                index += 1
                continue
            }

            // Headers
            if line.hasPrefix("### ") {
                tokens.append(.h3(String(line.dropFirst(4))))
                index += 1
                continue
            }
            if line.hasPrefix("## ") {
                tokens.append(.h2(String(line.dropFirst(3))))
                index += 1
                continue
            }
            if line.hasPrefix("# ") {
                tokens.append(.h1(String(line.dropFirst(2))))
                index += 1
                continue
            }

            // Bullet list item
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let content = String(line.dropFirst(2))
                let attributed = renderInline(content)
                tokens.append(.bullet(attributed))
                index += 1
                continue
            }

            // Blank line — skip
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Paragraph: coalesce consecutive non-blank, non-header lines
            var paragraphLines: [String] = [line]
            index += 1
            while index < lines.count {
                let next = lines[index]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty
                    || nextTrimmed.hasPrefix("#")
                    || nextTrimmed.hasPrefix("```")
                    || nextTrimmed.hasPrefix("- ")
                    || nextTrimmed.hasPrefix("* ")
                    || nextTrimmed == "---" {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            let paragraphText = paragraphLines.joined(separator: " ")
            tokens.append(.paragraph(renderInline(paragraphText)))
        }

        return tokens
    }

    // MARK: Inline Rendering

    /// Converts inline Markdown (bold, italic, code, LaTeX) to `NSAttributedString`.
    static func renderInline(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text

        // Base attributes
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.label
        ]

        while !remaining.isEmpty {
            // Bold **text** or __text__
            if let range = matchRange(in: remaining, pattern: #"\*\*(.+?)\*\*|__(.+?)__"#) {
                let prefix = String(remaining[remaining.startIndex..<range.lowerBound])
                if !prefix.isEmpty {
                    result.append(NSAttributedString(string: prefix, attributes: baseAttributes))
                }
                let matched = String(remaining[range])
                let inner = matched.dropFirst(2).dropLast(2)
                let boldFont = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
                result.append(NSAttributedString(string: String(inner), attributes: [
                    .font: boldFont,
                    .foregroundColor: UIColor.label
                ]))
                remaining = String(remaining[range.upperBound...])
                continue
            }

            // Italic *text* or _text_
            if let range = matchRange(in: remaining, pattern: #"\*([^\*]+?)\*|_([^_]+?)_"#) {
                let prefix = String(remaining[remaining.startIndex..<range.lowerBound])
                if !prefix.isEmpty {
                    result.append(NSAttributedString(string: prefix, attributes: baseAttributes))
                }
                let matched = String(remaining[range])
                let inner = matched.dropFirst(1).dropLast(1)
                let italicFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
                result.append(NSAttributedString(string: String(inner), attributes: [
                    .font: italicFont,
                    .foregroundColor: UIColor.label
                ]))
                remaining = String(remaining[range.upperBound...])
                continue
            }

            // Inline code `code`
            if let range = matchRange(in: remaining, pattern: #"`([^`]+?)`"#) {
                let prefix = String(remaining[remaining.startIndex..<range.lowerBound])
                if !prefix.isEmpty {
                    result.append(NSAttributedString(string: prefix, attributes: baseAttributes))
                }
                let matched = String(remaining[range])
                let inner = matched.dropFirst(1).dropLast(1)
                let codeFont = UIFont.monospacedSystemFont(
                    ofSize: baseFont.pointSize * 0.9, weight: .regular)
                result.append(NSAttributedString(string: String(inner), attributes: [
                    .font: codeFont,
                    .foregroundColor: UIColor.systemGreen,
                    .backgroundColor: UIColor.secondarySystemBackground
                ]))
                remaining = String(remaining[range.upperBound...])
                continue
            }

            // Inline LaTeX $formula$
            if let range = matchRange(in: remaining, pattern: #"\$([^\$\n]+?)\$"#) {
                let prefix = String(remaining[remaining.startIndex..<range.lowerBound])
                if !prefix.isEmpty {
                    result.append(NSAttributedString(string: prefix, attributes: baseAttributes))
                }
                let matched = String(remaining[range])
                let latexFont = UIFont.monospacedSystemFont(
                    ofSize: baseFont.pointSize * 0.9, weight: .regular)
                result.append(NSAttributedString(string: matched, attributes: [
                    .font: latexFont,
                    .foregroundColor: UIColor.systemIndigo
                ]))
                remaining = String(remaining[range.upperBound...])
                continue
            }

            // No more patterns — append the whole remaining string.
            result.append(NSAttributedString(string: remaining, attributes: baseAttributes))
            break
        }

        return result
    }

    // MARK: Helper

    private static func matchRange(
        in string: String,
        pattern: String
    ) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: nsRange),
              let range = Range(match.range, in: string)
        else { return nil }
        return range
    }
}

// MARK: - Preview

#Preview {
    MarkdownPreviewView(markdownContent: """
    # 论文标题示例

    ## 摘要

    这是一个 **粗体** 和 *斜体* 的示例段落。
    还有 `代码片段` 在行内显示。

    ### 公式示例

    行内公式: $E = mc^2$ 就是著名的质能方程。

    $$
    \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
    $$

    ## 代码示例

    ```python
    def hello():
        print("Hello, World!")
    ```

    ## 列表

    - 第一条要点
    - 第二条要点，包含 **加粗** 文字
    - 第三条要点

    ---

    结论部分内容。
    """)
}
