import Foundation

enum LLMProviderRegistry {

    static let allProviders: [PresetProvider] = [
        // 1. OpenAI
        PresetProvider(
            id: "openai",
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            models: [
                PresetModel(id: "gpt-4.1", name: "GPT-4.1"),
                PresetModel(id: "gpt-4.1-mini", name: "GPT-4.1 Mini"),
                PresetModel(id: "gpt-4.1-nano", name: "GPT-4.1 Nano"),
                PresetModel(id: "gpt-4o", name: "GPT-4o"),
                PresetModel(id: "gpt-4o-mini", name: "GPT-4o Mini"),
                PresetModel(id: "o4-mini", name: "o4-mini"),
                PresetModel(id: "o3", name: "o3"),
                PresetModel(id: "o3-mini", name: "o3-mini"),
            ]
        ),
        // 2. Claude (Anthropic)
        PresetProvider(
            id: "anthropic",
            name: "Claude (Anthropic)",
            baseURL: "https://api.anthropic.com/v1",
            models: [
                PresetModel(id: "claude-opus-4-6-20260201", name: "Claude Opus 4.6"),
                PresetModel(id: "claude-sonnet-4-6-20260201", name: "Claude Sonnet 4.6"),
                PresetModel(id: "claude-sonnet-4-5-20250514", name: "Claude Sonnet 4.5"),
                PresetModel(id: "claude-opus-4-5-20250514", name: "Claude Opus 4.5"),
                PresetModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5"),
            ]
        ),
        // 3. Google Gemini
        PresetProvider(
            id: "google",
            name: "Google Gemini",
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            models: [
                PresetModel(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro"),
                PresetModel(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash"),
                PresetModel(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash"),
                PresetModel(id: "gemini-2.0-flash-lite", name: "Gemini 2.0 Flash Lite"),
            ]
        ),
        // 4. DeepSeek
        PresetProvider(
            id: "deepseek",
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            models: [
                PresetModel(id: "deepseek-chat", name: "DeepSeek V3"),
                PresetModel(id: "deepseek-reasoner", name: "DeepSeek R1"),
            ]
        ),
        // 5. 智谱 GLM
        PresetProvider(
            id: "zhipu",
            name: "智谱 (GLM)",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            models: [
                PresetModel(id: "glm-4-plus", name: "GLM-4 Plus"),
                PresetModel(id: "glm-4-flash", name: "GLM-4 Flash"),
                PresetModel(id: "glm-4-long", name: "GLM-4 Long"),
                PresetModel(id: "glm-4-air", name: "GLM-4 Air"),
            ]
        ),
        // 6. 通义千问 (DashScope)
        PresetProvider(
            id: "dashscope",
            name: "通义千问 (DashScope)",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            models: [
                PresetModel(id: "qwen-max", name: "Qwen Max"),
                PresetModel(id: "qwen-plus", name: "Qwen Plus"),
                PresetModel(id: "qwen-turbo", name: "Qwen Turbo"),
                PresetModel(id: "qwen-long", name: "Qwen Long"),
                PresetModel(id: "qwen3-235b-a22b", name: "Qwen3 235B"),
            ]
        ),
        // 7. Minimax
        PresetProvider(
            id: "minimax",
            name: "Minimax",
            baseURL: "https://api.minimax.chat/v1",
            models: [
                PresetModel(id: "MiniMax-M1", name: "MiniMax M1"),
                PresetModel(id: "MiniMax-Text-01", name: "MiniMax Text 01"),
                PresetModel(id: "abab6.5s-chat", name: "ABAB 6.5s Chat"),
            ]
        ),
        // 8. OpenRouter (supports dynamic model discovery)
        PresetProvider(
            id: "openrouter",
            name: "OpenRouter",
            baseURL: "https://openrouter.ai/api/v1",
            models: [
                PresetModel(id: "anthropic/claude-opus-4-6", name: "Claude Opus 4.6"),
                PresetModel(id: "anthropic/claude-sonnet-4-6", name: "Claude Sonnet 4.6"),
                PresetModel(id: "openai/gpt-4.1", name: "GPT-4.1"),
                PresetModel(id: "google/gemini-2.5-pro", name: "Gemini 2.5 Pro"),
                PresetModel(id: "deepseek/deepseek-chat-v3-0324", name: "DeepSeek V3"),
            ],
            supportsModelDiscovery: true
        ),
    ]

    static func provider(id: String) -> PresetProvider? {
        allProviders.first { $0.id == id }
    }
}
