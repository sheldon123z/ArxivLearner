## ADDED Requirements

### Requirement: 服务商选择器
SettingsView 的 LLM 配置区域 SHALL 展示服务商选择器（Picker），列出所有预置服务商及"自定义"选项。

#### Scenario: 展示服务商列表
- **WHEN** 用户打开设置页面的 LLM 配置区域
- **THEN** 显示 Picker，选项包含 OpenAI、Claude、DeepSeek、智谱、通义千问、Minimax、OpenRouter 及"自定义"

#### Scenario: 选择预置服务商
- **WHEN** 用户从 Picker 选择 "DeepSeek"
- **THEN** Base URL 自动填充为 DeepSeek 的端点，模型选择器显示 DeepSeek 的预置模型

### Requirement: 模型选择器
选择预置服务商后，系统 SHALL 展示该服务商的模型选择器（Picker），列出可用模型。

#### Scenario: 展示预置模型列表
- **WHEN** 用户选择了服务商 "OpenAI"
- **THEN** 模型 Picker 显示 gpt-4o、gpt-4o-mini、o1、o3-mini 等模型

#### Scenario: 切换服务商后模型列表更新
- **WHEN** 用户从 OpenAI 切换到 DeepSeek
- **THEN** 模型 Picker 立即更新为 DeepSeek 的模型列表，并默认选中第一个模型

### Requirement: API Key 输入
无论选择预置服务商还是自定义，系统 SHALL 始终显示 API Key 输入框（SecureField）。

#### Scenario: API Key 输入
- **WHEN** 用户选择了服务商并输入 API Key
- **THEN** SecureField 接受输入，值不以明文展示

### Requirement: 自定义服务商模式
选择"自定义"时，系统 SHALL 显示完整的手动配置表单，包括服务商名称、Base URL、Model ID 和 API Key。

#### Scenario: 切换到自定义模式
- **WHEN** 用户在服务商 Picker 中选择"自定义"
- **THEN** 显示服务商名称 TextField、Base URL TextField 和 Model ID TextField
- **THEN** 隐藏模型选择 Picker

#### Scenario: 自定义模式保留手动输入值
- **WHEN** 用户在自定义模式下输入 Base URL 和 Model ID
- **THEN** 这些值直接用于生成 LLMProviderConfig，providerId 为 nil

### Requirement: 保存并测试
系统 SHALL 提供"保存并测试"按钮，将当前配置（无论预置还是自定义）保存并执行连接测试。

#### Scenario: 保存预置服务商配置
- **WHEN** 用户选择 OpenAI / gpt-4o，输入 API Key，点击"保存并测试"
- **THEN** 系统保存 LLMProviderConfig（providerId="openai", baseURL 自动填充, modelId="gpt-4o"）
- **THEN** API Key 存入 Keychain
- **THEN** 发起连接测试请求

#### Scenario: 连接测试成功
- **WHEN** 连接测试收到有效响应
- **THEN** 显示"连接成功"提示

#### Scenario: 连接测试失败
- **WHEN** 连接测试失败（网络错误/认证失败）
- **THEN** 显示对应错误提示

### Requirement: 恢复已保存的配置
打开设置页时，系统 SHALL 加载并展示用户上次保存的 LLM 配置。

#### Scenario: 恢复预置服务商配置
- **WHEN** 用户上次保存了 providerId="deepseek" 的配置
- **THEN** 设置页服务商 Picker 默认选中 DeepSeek，模型 Picker 选中已保存的模型

#### Scenario: 恢复自定义配置
- **WHEN** 用户上次保存了 providerId=nil 的配置
- **THEN** 设置页服务商 Picker 默认选中"自定义"，显示手动输入字段并填充已保存值
