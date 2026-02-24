## Context

ArxivLearner 当前的 LLM 配置采用纯手动输入方式（SettingsView 中 4 个 TextField），用户需要自行查找服务商的 Base URL 和 Model ID。现有架构：
- `LLMProviderConfig`：Codable 结构体，存储 name/baseURL/apiKey/modelId
- `OpenAICompatibleService`：基于 OpenAI Chat Completions 协议的通用服务实现
- 配置通过 UserDefaults + Keychain 持久化

绝大多数主流 LLM 服务商（DeepSeek、智谱、通义千问、Minimax 等）都兼容 OpenAI 协议，因此 `OpenAICompatibleService` 无需修改，只需在配置层提供预置数据。

## Goals / Non-Goals

**Goals:**
- 用户选择服务商后自动填充 Base URL，选择模型后自动填充 Model ID，只需输入 API Key
- 覆盖 OpenAI、Claude(Anthropic)、DeepSeek、智谱(GLM)、通义千问(DashScope)、Minimax、OpenRouter 7 个主流服务商
- OpenRouter 支持通过 API 动态拉取可用模型列表
- 保留自定义服务商入口供高级用户使用
- 配置数据向后兼容，旧版配置可正常加载

**Non-Goals:**
- 不实现多 LLM 配置切换（当前仍为单一活跃配置）
- 不实现 API Key 的服务端验证（仅本地连接测试）
- 不修改 `OpenAICompatibleService` 的请求/响应逻辑
- 不实现 OpenRouter 以外服务商的动态模型列表（其他服务商使用静态预置列表）

## Decisions

### D1: 预置数据存储方式 — 硬编码静态数组

将服务商注册表定义为 Swift 静态常量（`[PresetProvider]` 数组），而非从 JSON/plist 文件加载。

**理由**: 服务商信息变更频率低，硬编码方式类型安全、零 I/O 开销、无需文件管理。未来如需远程更新可追加网络层，当前不过度设计。

**替代方案**: JSON 资源文件 — 增加了文件解析复杂度，对 7 个服务商来说不值得。

### D2: 数据模型 — 新增 PresetProvider 与 PresetModel

```swift
struct PresetProvider {
    let id: String           // e.g. "openai", "deepseek"
    let name: String         // 显示名称
    let baseURL: String      // API 端点
    let models: [PresetModel]  // 预置模型列表
    let supportsModelDiscovery: Bool  // 是否支持动态获取模型
}

struct PresetModel {
    let id: String       // e.g. "gpt-4o"
    let name: String     // 显示名称
}
```

`LLMProviderConfig` 增加 `providerId: String?` 字段（可选，nil 表示自定义配置），保持向后兼容。

**理由**: 与现有 `LLMProviderConfig` 解耦，预置数据为只读引用，用户选择后仍生成 `LLMProviderConfig` 供 `OpenAICompatibleService` 使用。

### D3: UI 交互流程 — 分步选择

SettingsView 中 LLM 配置区域重构为：
1. **服务商选择**: Picker 展示预置服务商列表 + "自定义" 选项
2. **模型选择**: 选择服务商后，Picker 展示该服务商的模型列表（OpenRouter 额外显示加载按钮）
3. **API Key 输入**: SecureField
4. **保存并测试**: 复用现有连接测试逻辑

选择"自定义"时退回到原有的手动输入模式（显示 Base URL 和 Model ID 输入框）。

**理由**: 最小化用户操作步骤，预置用户只需 3 步（选服务商 → 选模型 → 填 Key），高级用户仍可手动配置。

### D4: OpenRouter 模型发现 — 独立 Service

新建 `OpenRouterModelService`，调用 `GET https://openrouter.ai/api/v1/models`，解析返回的模型列表。

- 请求不需要 API Key（公开接口）
- 返回结果缓存在内存中（`@State` 层面），不做磁盘持久化
- UI 上用"获取模型列表"按钮触发，显示 loading 状态

**理由**: OpenRouter 的 models API 是公开的，无需认证。内存缓存足够（用户每次进入设置页最多触发一次），无需复杂的缓存策略。

### D5: 各服务商 API 端点与预置模型

| 服务商 | Base URL | 预置模型 |
|--------|----------|---------|
| OpenAI | `https://api.openai.com/v1` | gpt-4o, gpt-4o-mini, o1, o3-mini |
| Claude (Anthropic) | `https://api.anthropic.com/v1` | claude-sonnet-4-20250514, claude-haiku-4-5-20251001 |
| DeepSeek | `https://api.deepseek.com/v1` | deepseek-chat, deepseek-reasoner |
| 智谱 (GLM) | `https://open.bigmodel.cn/api/paas/v4` | glm-4-plus, glm-4-flash |
| 通义千问 (DashScope) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | qwen-plus, qwen-turbo, qwen-max |
| Minimax | `https://api.minimax.chat/v1` | MiniMax-Text-01, abab6.5s-chat |
| OpenRouter | `https://openrouter.ai/api/v1` | (动态获取，预置 3 个热门模型作为 fallback) |

## Risks / Trade-offs

- **服务商 API 变更**: Base URL 或模型 ID 可能随服务商更新而失效 → 硬编码便于快速修复发版，且用户始终可切换到自定义模式
- **Anthropic Claude 协议差异**: Claude API 的请求格式与 OpenAI 不完全相同（如 system message 处理方式）→ 当前 `OpenAICompatibleService` 对大多数场景够用，Claude 兼容层的细微差异留待后续迭代
- **OpenRouter API 不可用**: 网络问题或 API 变更导致模型列表获取失败 → 预置 fallback 模型列表，获取失败时使用静态列表
- **旧配置迁移**: `providerId` 字段为可选，旧数据反序列化时自动为 nil（即自定义模式），无破坏性
