import Foundation

// MARK: - ProviderType

/// Identifies the LLM service provider type.
/// Stored as a String rawValue in SwiftData; use LLMProvider.type for typed access.
enum ProviderType: String, Codable, CaseIterable {
    // International providers
    case openai
    case anthropic
    case google
    case deepseek
    case openRouter
    case customOpenAI

    // Chinese providers (matching existing LLMProviderRegistry entries)
    case zhipu
    case dashscope
    case minimax

    /// A human-readable display name for each provider type.
    var displayName: String {
        switch self {
        case .openai:       return "OpenAI"
        case .anthropic:    return "Anthropic (Claude)"
        case .google:       return "Google (Gemini)"
        case .deepseek:     return "DeepSeek"
        case .openRouter:   return "OpenRouter"
        case .customOpenAI: return "自定义 (OpenAI 兼容)"
        case .zhipu:        return "智谱 (GLM)"
        case .dashscope:    return "通义千问 (DashScope)"
        case .minimax:      return "Minimax"
        }
    }
}

// MARK: - PromptScene

/// Describes the intended use-case for a PromptTemplate.
/// Stored as a String rawValue in SwiftData; use PromptTemplate.scene for typed access.
enum PromptScene: String, Codable, CaseIterable {
    case globalSystem
    case insightGeneration
    case innovationExtract
    case formulaAnalysis
    case paperChat
    case translation
    case summary
    case custom

    /// A localized display label suitable for use in the UI.
    var displayName: String {
        switch self {
        case .globalSystem:       return "全局系统"
        case .insightGeneration:  return "核心见解"
        case .innovationExtract:  return "创新点提取"
        case .formulaAnalysis:    return "公式解析"
        case .paperChat:          return "论文问答"
        case .translation:        return "全文翻译"
        case .summary:            return "摘要总结"
        case .custom:             return "自定义"
        }
    }
}

// MARK: - OutputFormat

/// Defines the expected format of the LLM response.
/// Stored as a String rawValue in SwiftData; use PromptTemplate.format for typed access.
enum OutputFormat: String, Codable, CaseIterable {
    case markdown
    case plainText
    case json

    /// A localized display label suitable for use in the UI.
    var displayName: String {
        switch self {
        case .markdown:  return "Markdown"
        case .plainText: return "纯文本"
        case .json:      return "JSON"
        }
    }
}

// MARK: - AnnotationType

enum AnnotationType: String, Codable, CaseIterable {
    case highlight
    case note

    var displayName: String {
        switch self {
        case .highlight: return "高亮"
        case .note:      return "注释"
        }
    }
}

// MARK: - AppearanceMode

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "始终浅色"
        case .dark:   return "始终深色"
        }
    }
}

// MARK: - RequestType

/// Classifies an LLM API call for usage tracking and analytics.
/// Stored as a String rawValue in SwiftData; use UsageRecord.requestType for typed access.
enum RequestType: String, Codable, CaseIterable {
    case insightGeneration
    case paperChat
    case translation
    case codeExplanation
    case figureAnalysis
    case summary
    case innovationExtract
    case formulaAnalysis

    /// A localized display label suitable for use in the UI.
    var displayName: String {
        switch self {
        case .insightGeneration: return "核心见解"
        case .paperChat:         return "论文问答"
        case .translation:       return "全文翻译"
        case .codeExplanation:   return "代码解释"
        case .figureAnalysis:    return "图表分析"
        case .summary:           return "摘要总结"
        case .innovationExtract: return "创新点提取"
        case .formulaAnalysis:   return "公式解析"
        }
    }
}
