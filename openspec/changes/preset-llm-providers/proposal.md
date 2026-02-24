## Why

当前 LLM 配置要求用户手动输入服务商名称、Base URL 和 Model ID，这对普通用户门槛过高，容易输错。需要提供主流 LLM 服务商的预配置方案，用户只需选择服务商、填写 API Key 即可开始使用。

## What Changes

- 新增预置 LLM 服务商注册表，内置 OpenAI、Claude(Anthropic)、DeepSeek、智谱(GLM)、通义千问(DashScope)、Minimax、OpenRouter 等服务商的 Base URL 和推荐模型列表
- **BREAKING**: 重构 `LLMProviderConfig` 模型，增加 `providerId` 字段标识预置服务商，区分预置与自定义配置
- 重构 SettingsView 的 LLM 配置区域，从手动输入改为"选择服务商 → 选择模型 → 填写 API Key"的引导式流程
- 新增 OpenRouter 模型列表动态获取功能，通过其 `/api/v1/models` API 拉取可用模型
- 保留"自定义服务商"选项，允许高级用户手动配置任意 OpenAI 兼容接口

## Capabilities

### New Capabilities

- `llm-provider-registry`: 预置 LLM 服务商注册表，定义各服务商的 ID、名称、Base URL、支持的模型列表、图标等元数据
- `llm-provider-selector`: 服务商选择与配置 UI 组件，包含服务商列表、模型选择器、API Key 输入、连接测试等交互流程
- `openrouter-model-discovery`: OpenRouter 模型动态发现功能，通过 API 获取可用模型列表并缓存

### Modified Capabilities

(无已有 spec 需要修改)

## Impact

- **Models**: `LLMProviderConfig` 增加字段，存储格式变化，需处理旧数据迁移
- **Settings UI**: `SettingsView` 的 LLM 配置区域完全重写
- **Network**: 新增 OpenRouter Models API 调用
- **Storage**: API Key 仍通过 Keychain 存储，服务商配置仍通过 UserDefaults 存储
- **LLM Service**: `OpenAICompatibleService` 无需修改，预置配置最终仍生成 `LLMProviderConfig` 供其使用
