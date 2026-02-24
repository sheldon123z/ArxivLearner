## Why

MVP 已完成搜索→浏览→下载→转换→AI见解的核心闭环，但仅支持单一 OpenAI 兼容服务商，卡片背面功能不完整（缺少创新点提取、公式解析、论文问答、全文翻译），且没有 Prompt 模板管理体系。第二期需要将 LLM 能力从"可用"提升到"全面可用"，支持用户自由选择多家模型服务商，并完善所有深度学习辅助功能。

## What Changes

- 新增多 LLM 服务商接入：预设 OpenAI / Anthropic / Google Gemini / DeepSeek / OpenRouter，支持自定义 OpenAI 兼容中转站
- 新增模型能力检测系统（ModelCapabilities），根据模型能力动态显示/隐藏功能按钮
- 新增连通性测试功能（一键 ping 测试服务商可用性）
- 完善卡片背面全部功能按钮：创新点提取（Sheet）、公式解析（Sheet）、论文问答（全屏多轮对话）、全文翻译（原文/译文对照）、展开全文详情、重新生成见解（支持切换模型）
- 新增 Prompt 模板体系：全局系统指令、6 个内置场景模板、变量系统（{{title}} {{abstract}} 等）、自定义模板、Prompt 编辑器、预览测试
- 新增模型分配系统：按场景绑定默认模型，Prompt 级覆盖
- 新增 PDF 阅读器增强：选中文本菜单（复制/翻译/解释/提问）、书签功能
- 新增 doc2x 增强：下载后自动转换、Markdown 预览、公式解析联动
- 新增用量统计：按模型/按场景的 token 消耗和费用统计、时间趋势图、月度费用预警

## Capabilities

### New Capabilities
- `multi-llm-provider`: 多 LLM 服务商管理，包括预设服务商配置、自定义中转站、模型能力检测、连通性测试、模型列表管理
- `prompt-template-system`: Prompt 模板体系，包括全局系统指令、内置场景模板、变量替换系统、自定义模板 CRUD、Prompt 编辑器 UI、预览测试
- `paper-chat`: 论文问答功能，基于论文内容的多轮对话，支持上下文策略（短论文全文注入、长论文分段匹配、多模态图表引用、PDF 直传）
- `card-analysis-features`: 卡片背面分析功能集合，包括创新点提取、公式解析、全文翻译（原文/译文对照）、展开全文详情、重新生成见解
- `model-assignment`: 模型分配系统，按场景绑定默认模型，Prompt 级绑定覆盖，优先级策略
- `pdf-reader-enhancement`: PDF 阅读器增强，选中文本上下文菜单（复制/翻译/解释/提问）、PDF 书签管理
- `doc2x-enhancement`: doc2x 服务增强，下载后自动转换、Markdown 内容预览、基于 LaTeX 的公式解析联动
- `usage-statistics`: 用量统计系统，按模型/按场景的 token 和费用追踪、日/周/月时间趋势图、月度预算预警

### Modified Capabilities
（无已有 specs 需要修改）

## Impact

- **Core/LLM/**: 重构 LLM 服务层，新增 AnthropicService、GeminiService、DeepSeekService、OpenRouterService，扩展 LLMServiceProtocol
- **Core/Storage/Models/**: 新增 LLMProvider、LLMModel（含 ModelCapabilities）、PromptTemplate、UsageRecord 完整 SwiftData 模型，替换当前简化版 LLMProviderModel
- **Features/Cards/**: FullCardView 背面新增 5 个功能按钮和对应的 Sheet/全屏页面
- **Features/Chat/**: 从占位状态实现完整的论文问答功能
- **Features/Reader/**: PDFReaderView 增加文本选中菜单和书签
- **Features/Settings/**: 大幅扩展，新增 ProviderSettingsView、PromptEditorView、UsageStatsView 等子页面
- **Resources/**: 新增 DefaultPrompts.json 内置模板数据
