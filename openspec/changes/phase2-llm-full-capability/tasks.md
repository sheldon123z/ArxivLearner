## 1. SwiftData 模型升级

- [x] 1.1 创建完整的 LLMProvider SwiftData 模型（id, name, providerType, baseURL, apiKey, customHeaders, isEnabled, sortOrder, models 关系, createdAt）
- [x] 1.2 创建完整的 LLMModel SwiftData 模型（id, provider 关系, modelId, displayName, contextWindow, maxOutputTokens, capabilities: ModelCapabilities, inputPricePerMToken, outputPricePerMToken, isDefault, isEnabled）
- [x] 1.3 创建 ModelCapabilities Codable 结构体（textInput, textOutput, imageInput, imageOutput, pdfInput, functionCalling, streaming, jsonMode, reasoning）
- [x] 1.4 创建 PromptTemplate SwiftData 模型（id, name, scene: PromptScene, systemPrompt, userPromptTemplate, responseLanguage, outputFormat, temperature, maxTokens, boundModel 关系, isBuiltIn, sortOrder）
- [x] 1.5 创建 UsageRecord SwiftData 模型（model 关系, date, inputTokens, outputTokens, estimatedCost, requestType）
- [x] 1.6 创建 PromptScene 和 OutputFormat 枚举
- [x] 1.7 删除旧的 LLMProviderModel，更新 ModelContainer 注册所有新模型
- [x] 1.8 创建 DefaultPrompts.json 包含 6 个内置场景模板数据

## 2. LLM 服务层扩展

- [x] 2.1 实现 AnthropicService（Messages API 格式，支持流式输出，搜索最新 API 文档）
- [x] 2.2 实现 GeminiService（generateContent API 格式，支持 pdfInput，搜索最新 API 文档）
- [x] 2.3 扩展 OpenAICompatibleService 支持 DeepSeek / OpenRouter 的 baseURL 配置
- [x] 2.4 实现 LLMRouter 路由器（根据 providerType 分发请求到对应 Service）
- [x] 2.5 实现服务商连通性测试功能（发送测试请求，返回延迟和状态）
- [x] 2.6 实现 OpenRouter 动态模型列表拉取

## 3. Prompt 模板系统

- [x] 3.1 实现变量替换引擎（替换 {{title}} {{abstract}} {{authors}} {{categories}} {{full_text}} {{selected_text}}，处理变量缺失）
- [x] 3.2 扩展 ContextBuilder 支持 PromptTemplate 驱动的请求构建
- [x] 3.3 实现 DefaultPrompts.json 首次启动加载逻辑（创建内置 PromptTemplate 实例）
- [x] 3.4 实现模型选择优先级解析（Prompt 绑定 > 场景默认 > 全局默认）

## 4. 论文问答功能

- [x] 4.1 创建 ChatViewModel（管理论文上下文、对话历史、流式输出、消息持久化）
- [x] 4.2 创建 ChatView 全屏对话页面（消息列表、输入框、发送按钮、停止按钮）
- [x] 4.3 实现智能上下文策略（短论文全文注入、长论文分段匹配、PDF 直传、纯文本降级）
- [x] 4.4 实现对话历史列表页面（在"对话"Tab 显示所有论文的对话，按最后消息时间排序）
- [x] 4.5 实现流式输出中断功能

## 5. 卡片背面分析功能

- [x] 5.1 创建 InnovationAnalysisView（Sheet 面板，创新点列表流式显示，缓存结果）
- [x] 5.2 创建 FormulaAnalysisView（Sheet 面板，公式提取和解释，支持 LaTeX 联动）
- [x] 5.3 创建 TranslationView（全屏页面，逐段翻译，原文/译文对照显示，进度指示）
- [x] 5.4 创建 PaperDetailView（全屏页面，完整论文信息 + Markdown 渲染 + PDF 入口）
- [x] 5.5 扩展 FullCardView 背面添加所有功能按钮（创新点/公式/问答/翻译/详情/重新生成）
- [x] 5.6 实现重新生成见解功能（支持切换模型，原地刷新动画）
- [x] 5.7 根据模型 capabilities 动态显示/隐藏功能按钮

## 6. 设置页扩展

- [x] 6.1 创建 ProviderSettingsView（服务商列表 + 添加预设/自定义服务商 + 编辑/删除/启用禁用/排序）
- [x] 6.2 创建 ProviderDetailView（服务商详情编辑 + 模型管理 + 连通性测试按钮）
- [x] 6.3 创建 PromptEditorView（system prompt 编辑 + user prompt 模板编辑 + 参数调节 + 预览测试）
- [x] 6.4 创建 ModelAssignmentView（场景级模型绑定选择界面）
- [x] 6.5 创建 GlobalSystemPromptView（全局系统指令编辑页）
- [x] 6.6 更新 SettingsView 主页面导航到所有子页面

## 7. PDF 阅读器增强

- [x] 7.1 实现 PDF 文本选中上下文菜单（复制/翻译/解释/提问）
- [x] 7.2 实现选中文本翻译/解释的浮动结果面板
- [x] 7.3 实现选中文本提问跳转到论文问答页面
- [x] 7.4 实现 PDF 书签管理（添加/查看列表/跳转/删除，持久化到 Paper 模型）

## 8. doc2x 增强

- [x] 8.1 实现下载后自动转换逻辑（设置项：下载后自动/仅手动/关闭）
- [x] 8.2 创建 MarkdownPreviewView（渲染 Markdown 内容，支持 LaTeX 公式显示）
- [x] 8.3 实现 LaTeX 公式提取工具（从 Markdown 提取 $...$ 和 $$...$$ 公式块）
- [x] 8.4 更新 Doc2xSettingsView（添加自动转换模式选择、用量显示）

## 9. 用量统计

- [x] 9.1 实现 LLM 请求用量自动记录（在 LLMRouter 完成请求后创建 UsageRecord）
- [x] 9.2 创建 UsageStatsView 主页面（按模型/按场景/时间趋势 Tab 切换）
- [x] 9.3 实现按模型统计视图（表格展示各模型 token 和费用汇总）
- [x] 9.4 实现按场景统计视图（饼图/柱状图展示各场景占比）
- [x] 9.5 实现时间趋势视图（Swift Charts 折线图，日/周/月维度）
- [x] 9.6 实现月度费用预警（设置预算、80% 黄色警告、超预算红色警告）

## 10. 集成与测试

- [x] 10.1 更新 ContentView Tab 导航接入所有新页面
- [x] 10.2 编写 LLMRouter 单元测试
- [x] 10.3 编写 PromptTemplate 变量替换单元测试
- [x] 10.4 编写 ChatViewModel 单元测试
- [x] 10.5 编写 UsageRecord 统计查询单元测试
- [x] 10.6 全流程集成验证：搜索 → 卡片 → 多模型见解 → 问答 → 翻译 → 用量统计
