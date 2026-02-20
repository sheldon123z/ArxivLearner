import Foundation

// MARK: - ContextBuilder

/// Builds LLM context strings from paper content, applying a priority strategy:
/// markdown > fullText > abstract.
enum ContextBuilder {

    // MARK: - PaperContext

    struct PaperContext {
        /// The paper title.
        let title: String
        /// The paper abstract (always required as a fallback).
        let abstractText: String
        /// Parsed Markdown representation of the paper body (highest priority).
        let markdownContent: String?
        /// Plain-text full content of the paper (used when markdown is unavailable).
        let fullText: String?
    }

    // MARK: - Public API

    /// Returns the best available content string for the given paper context.
    /// Priority order: markdownContent > fullText > abstractText.
    static func buildContext(for paper: PaperContext) -> String {
        let body: String
        if let markdown = paper.markdownContent, !markdown.isEmpty {
            body = markdown
        } else if let full = paper.fullText, !full.isEmpty {
            body = full
        } else {
            body = paper.abstractText
        }

        return """
        标题: \(paper.title)

        \(body)
        """
    }

    /// Returns the system prompt used for Chinese academic paper analysis.
    static func insightSystemPrompt() -> String {
        """
        你是一位专业的学术论文助手，擅长分析和解读人工智能与机器学习领域的研究论文。
        请使用中文回答所有问题，语言简洁清晰，适合研究人员和学生阅读。
        在分析论文时，请重点关注：研究问题、核心方法、实验结果以及对领域的贡献。
        如遇到专业术语，可保留英文原文并附上中文解释。
        """
    }
}
