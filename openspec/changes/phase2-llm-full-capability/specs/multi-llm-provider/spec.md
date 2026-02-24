## ADDED Requirements

### Requirement: 支持多 LLM 服务商配置
系统 SHALL 支持配置多个 LLM 服务商，包括预设服务商（OpenAI、Anthropic、Google Gemini、DeepSeek、OpenRouter）和自定义 OpenAI 兼容中转站。每个服务商 MUST 包含名称、providerType、baseURL、apiKey 字段。

#### Scenario: 添加预设服务商
- **WHEN** 用户在设置页选择添加预设服务商（如 Anthropic）
- **THEN** 系统自动填充 baseURL，用户仅需输入 apiKey

#### Scenario: 添加自定义中转站
- **WHEN** 用户选择添加自定义 OpenAI 兼容服务商
- **THEN** 系统 SHALL 要求用户输入 baseURL、apiKey，可选输入 customHeaders

#### Scenario: 管理已有服务商
- **WHEN** 用户查看服务商列表
- **THEN** 系统 SHALL 显示所有已配置的服务商，支持启用/禁用、编辑、删除、排序

### Requirement: 模型能力检测
每个 LLM 模型 MUST 声明其 ModelCapabilities，包括 textInput、textOutput、imageInput、imageOutput、pdfInput、functionCalling、streaming、jsonMode、reasoning。

#### Scenario: 根据模型能力显示功能按钮
- **WHEN** 用户查看卡片背面功能按钮
- **THEN** 系统 SHALL 根据当前选择模型的能力动态显示/隐藏功能按钮（如无 streaming 则隐藏流式输出选项）

#### Scenario: 配置模型能力
- **WHEN** 用户添加或编辑模型
- **THEN** 系统 SHALL 允许设置模型的 contextWindow、maxOutputTokens、能力标记、定价信息

### Requirement: 服务商连通性测试
系统 SHALL 提供一键测试服务商 API 连通性的功能。

#### Scenario: 测试成功
- **WHEN** 用户点击连通性测试按钮且 API 响应正常
- **THEN** 系统 SHALL 显示绿色勾号和响应延迟时间

#### Scenario: 测试失败
- **WHEN** 用户点击连通性测试按钮且 API 无响应或返回错误
- **THEN** 系统 SHALL 显示红色叉号和错误信息

### Requirement: LLMRouter 统一路由
系统 SHALL 通过 LLMRouter 根据模型的 providerType 自动路由请求到对应的 Service 实现。ViewModel 层 MUST NOT 直接依赖具体 Service 实现。

#### Scenario: 路由到正确的服务商
- **WHEN** ViewModel 通过 LLMRouter 发起请求，指定一个 Anthropic 模型
- **THEN** LLMRouter SHALL 将请求路由到 AnthropicService

#### Scenario: 服务商不可用
- **WHEN** 指定模型的服务商未配置或已禁用
- **THEN** LLMRouter SHALL 返回明确的错误信息，不进行降级
