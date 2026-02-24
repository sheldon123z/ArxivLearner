## ADDED Requirements

### Requirement: 全局系统指令
系统 SHALL 支持配置全局系统指令（globalSystem），该指令 MUST 注入到所有 LLM 请求的 system prompt 前部。

#### Scenario: 全局指令注入
- **WHEN** 任何 LLM 请求被构建
- **THEN** 全局系统指令 SHALL 作为 system message 的第一部分被包含

#### Scenario: 编辑全局指令
- **WHEN** 用户在设置页编辑全局系统指令
- **THEN** 修改 SHALL 立即生效，影响后续所有 LLM 请求

### Requirement: 内置场景模板
系统 SHALL 提供 6 个内置场景 Prompt 模板：见解生成（insightGeneration）、创新点提取（innovationExtract）、公式解析（formulaAnalysis）、论文问答（paperChat）、全文翻译（translation）、摘要生成（summary）。

#### Scenario: 加载内置模板
- **WHEN** 应用首次启动
- **THEN** 系统 SHALL 从 DefaultPrompts.json 加载 6 个内置模板，标记为 isBuiltIn=true

#### Scenario: 内置模板不可删除
- **WHEN** 用户尝试删除内置模板
- **THEN** 系统 SHALL 禁止删除，可提供"恢复默认"操作

### Requirement: 变量替换系统
Prompt 模板 MUST 支持变量占位符，系统在构建 LLM 请求时 SHALL 自动替换。支持的变量包括：`{{title}}`、`{{abstract}}`、`{{authors}}`、`{{categories}}`、`{{full_text}}`、`{{selected_text}}`。

#### Scenario: 变量自动替换
- **WHEN** 系统使用 Prompt 模板构建请求，当前论文标题为 "Attention Is All You Need"
- **THEN** 模板中的 `{{title}}` SHALL 被替换为 "Attention Is All You Need"

#### Scenario: 变量缺失时处理
- **WHEN** 模板包含 `{{full_text}}` 但论文无 Markdown/全文内容
- **THEN** 系统 SHALL 将该变量替换为空字符串，并在模板中标注"（全文内容不可用）"

### Requirement: 自定义 Prompt 模板
用户 SHALL 能够创建、编辑、删除自定义 Prompt 模板。每个模板包含：名称、场景类型、systemPrompt、userPromptTemplate、responseLanguage、outputFormat、temperature、maxTokens。

#### Scenario: 创建自定义模板
- **WHEN** 用户在 Prompt 编辑器中填写模板信息并保存
- **THEN** 系统 SHALL 创建新的自定义模板，isBuiltIn=false

#### Scenario: Prompt 编辑器 UI
- **WHEN** 用户打开 Prompt 编辑器
- **THEN** 系统 SHALL 显示 system prompt 输入区、user prompt 模板输入区、参数调节控件（temperature 滑块、maxTokens 输入、语言选择、输出格式选择）

### Requirement: Prompt 预览测试
系统 SHALL 支持选择一篇论文测试 Prompt 模板效果。

#### Scenario: 预览 Prompt 输出
- **WHEN** 用户在 Prompt 编辑器中点击"测试"并选择一篇论文
- **THEN** 系统 SHALL 显示变量替换后的完整 prompt 内容，并调用 LLM 生成预览结果
