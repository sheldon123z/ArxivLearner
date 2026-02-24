## ADDED Requirements

### Requirement: 论文多轮问答
系统 SHALL 支持基于单篇论文内容的多轮对话，对话历史 MUST 持久化到 SwiftData（ChatMessage 模型）。

#### Scenario: 发起论文问答
- **WHEN** 用户从卡片背面点击"论文问答"按钮
- **THEN** 系统 SHALL 打开全屏对话页面，自动加载论文上下文，显示历史对话记录

#### Scenario: 多轮对话
- **WHEN** 用户发送消息
- **THEN** 系统 SHALL 将论文上下文 + 历史消息 + 用户消息发送给 LLM，流式显示回复，并保存到 ChatMessage

#### Scenario: 对话列表
- **WHEN** 用户进入"对话"Tab
- **THEN** 系统 SHALL 显示所有论文的对话历史列表，按最后消息时间排序

### Requirement: 智能上下文策略
系统 SHALL 根据论文内容长度和模型能力自动选择最优上下文注入策略。

#### Scenario: 短论文全文注入
- **WHEN** 论文有 Markdown 内容且文本长度 < 模型 contextWindow 的 50%
- **THEN** 系统 SHALL 将全文注入 system prompt

#### Scenario: 长论文分段匹配
- **WHEN** 论文有 Markdown 内容且文本长度 > 模型 contextWindow 的 50%
- **THEN** 系统 SHALL 按 section 分段，根据用户问题关键词匹配相关段落注入

#### Scenario: PDF 直传模型
- **WHEN** 当前模型支持 pdfInput 能力且论文已下载 PDF
- **THEN** 系统 SHALL 直接发送 PDF 文件给模型

#### Scenario: 降级纯文本
- **WHEN** 无 Markdown、无 pdfInput 能力
- **THEN** 系统 SHALL 使用 PDFKit 提取纯文本作为上下文

### Requirement: 流式对话输出
论文问答 MUST 支持流式输出（SSE），逐字显示 LLM 回复内容。

#### Scenario: 流式显示回复
- **WHEN** LLM 开始返回流式响应
- **THEN** 系统 SHALL 实时追加显示文本，完成后保存完整回复到 ChatMessage

#### Scenario: 中断流式输出
- **WHEN** 用户在流式输出过程中点击"停止"按钮
- **THEN** 系统 SHALL 中断请求，保存已接收的部分回复
