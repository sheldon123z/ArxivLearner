## ADDED Requirements

### Requirement: PresetProvider 数据结构
系统 SHALL 定义 `PresetProvider` 结构体，包含以下字段：
- `id: String` — 唯一标识符（kebab-case，如 "openai"、"deepseek"）
- `name: String` — 用户可见的显示名称
- `baseURL: String` — API 端点地址
- `models: [PresetModel]` — 该服务商预置的模型列表
- `supportsModelDiscovery: Bool` — 是否支持动态获取模型列表

#### Scenario: 结构体字段完整性
- **WHEN** 创建一个 PresetProvider 实例
- **THEN** 所有字段 MUST 具有有效值，id 不为空，baseURL 为合法 URL 格式

### Requirement: PresetModel 数据结构
系统 SHALL 定义 `PresetModel` 结构体，包含以下字段：
- `id: String` — 模型标识符（用于 API 请求）
- `name: String` — 用户可见的显示名称

#### Scenario: 模型标识唯一
- **WHEN** 同一 PresetProvider 下定义多个 PresetModel
- **THEN** 每个 PresetModel 的 id MUST 在该 Provider 范围内唯一

### Requirement: 预置服务商注册表
系统 SHALL 提供静态注册表 `LLMProviderRegistry`，包含以下预置服务商：
1. OpenAI（baseURL: `https://api.openai.com/v1`）
2. Claude / Anthropic（baseURL: `https://api.anthropic.com/v1`）
3. DeepSeek（baseURL: `https://api.deepseek.com/v1`）
4. 智谱 GLM（baseURL: `https://open.bigmodel.cn/api/paas/v4`）
5. 通义千问 DashScope（baseURL: `https://dashscope.aliyuncs.com/compatible-mode/v1`）
6. Minimax（baseURL: `https://api.minimax.chat/v1`）
7. OpenRouter（baseURL: `https://openrouter.ai/api/v1`，supportsModelDiscovery = true）

#### Scenario: 获取所有预置服务商
- **WHEN** 调用 `LLMProviderRegistry.allProviders`
- **THEN** 返回包含 7 个 PresetProvider 的数组，按上述顺序排列

#### Scenario: 按 ID 查找服务商
- **WHEN** 调用 `LLMProviderRegistry.provider(id: "deepseek")`
- **THEN** 返回 DeepSeek 对应的 PresetProvider 实例

#### Scenario: 查找不存在的服务商
- **WHEN** 调用 `LLMProviderRegistry.provider(id: "unknown")`
- **THEN** 返回 nil

### Requirement: 每个预置服务商包含推荐模型
每个预置服务商 SHALL 包含至少 2 个预置模型，涵盖该服务商的主力模型。

#### Scenario: OpenAI 预置模型
- **WHEN** 获取 OpenAI 的预置模型列表
- **THEN** 列表包含 gpt-4o 和 gpt-4o-mini

#### Scenario: DeepSeek 预置模型
- **WHEN** 获取 DeepSeek 的预置模型列表
- **THEN** 列表包含 deepseek-chat 和 deepseek-reasoner

### Requirement: LLMProviderConfig 增加 providerId 字段
`LLMProviderConfig` SHALL 新增可选字段 `providerId: String?`，用于标识当前配置来源于哪个预置服务商。值为 nil 时表示自定义配置。

#### Scenario: 从预置服务商创建配置
- **WHEN** 用户选择预置服务商 "openai" 和模型 "gpt-4o"
- **THEN** 生成的 LLMProviderConfig 的 providerId 为 "openai"，baseURL 和 modelId 自动填充

#### Scenario: 旧版配置兼容
- **WHEN** 反序列化不含 providerId 字段的旧版 JSON 数据
- **THEN** providerId 自动解码为 nil，其他字段正常加载
