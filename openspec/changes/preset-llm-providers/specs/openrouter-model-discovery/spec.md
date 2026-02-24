## ADDED Requirements

### Requirement: OpenRouter 模型列表获取
当用户选择 OpenRouter 作为服务商时，系统 SHALL 提供"获取模型列表"功能，通过 OpenRouter 的公开 API 获取可用模型。

#### Scenario: 获取模型列表成功
- **WHEN** 用户选择 OpenRouter 并点击"获取模型列表"按钮
- **THEN** 系统调用 `GET https://openrouter.ai/api/v1/models`
- **THEN** 解析返回的模型列表并更新模型选择器

#### Scenario: 获取过程中显示加载状态
- **WHEN** 模型列表请求正在进行中
- **THEN** 按钮显示 loading 指示器，禁止重复点击

### Requirement: OpenRouter API 响应解析
系统 SHALL 从 OpenRouter models API 响应中解析模型信息，提取 `id` 和 `name` 字段。

#### Scenario: 解析标准响应
- **WHEN** API 返回 `{ "data": [{ "id": "openai/gpt-4o", "name": "GPT-4o", ... }] }`
- **THEN** 每个模型解析为 PresetModel，id 取 "openai/gpt-4o"，name 取 "GPT-4o"

#### Scenario: 过滤不可用模型
- **WHEN** API 返回的模型列表中包含非 chat 类型的模型
- **THEN** 这些模型仍然显示在列表中（不做过滤，由用户自行选择）

### Requirement: 获取失败时使用 Fallback 模型
当 OpenRouter 模型列表获取失败时，系统 SHALL 使用预置的 fallback 模型列表。

#### Scenario: 网络错误 fallback
- **WHEN** 调用 OpenRouter models API 发生网络错误
- **THEN** 模型选择器显示预置的 fallback 模型列表
- **THEN** 向用户显示获取失败的提示信息

#### Scenario: Fallback 模型列表内容
- **WHEN** 使用 fallback 模型列表
- **THEN** 列表至少包含 3 个热门 OpenRouter 模型

### Requirement: OpenRouterModelService
系统 SHALL 提供 `OpenRouterModelService` 类，封装 OpenRouter 模型列表的获取逻辑。

#### Scenario: 服务初始化
- **WHEN** 创建 OpenRouterModelService 实例
- **THEN** 实例可注入自定义 URLSession 以支持单元测试

#### Scenario: 调用 fetchModels
- **WHEN** 调用 `fetchModels()` 方法
- **THEN** 返回 `[PresetModel]` 数组
- **THEN** 方法为 async throws，支持异步调用
