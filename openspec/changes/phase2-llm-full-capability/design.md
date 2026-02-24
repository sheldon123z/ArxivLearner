## Context

ArxivLearner MVP 已完成核心闭环：arXiv 搜索 → 卡片浏览 → PDF 下载 → doc2x 转换 → LLM 见解生成。当前 LLM 层仅支持单一 OpenAI 兼容服务（OpenAICompatibleService），卡片背面只有见解生成，Chat 功能为占位状态，无 Prompt 模板管理，无用量统计。

现有架构基于 SwiftUI + SwiftData + MVVM，按 Feature 分层。LLM 服务层已定义 LLMServiceProtocol，具备扩展基础。

## Goals / Non-Goals

**Goals:**
- 扩展 LLM 服务层支持 5+ 服务商，保持统一协议
- 实现完整的 Prompt 模板体系，支持变量替换和场景绑定
- 完善卡片背面所有分析功能（创新点/公式/问答/翻译/详情/重生成）
- 实现论文多轮问答，支持智能上下文策略
- 构建用量追踪系统

**Non-Goals:**
- iCloud 同步（第三期）
- 滑动浏览模式（第三期）
- 标签系统（第三期）
- PDF 注释/侧边 AI 面板（第三期）
- 搜索历史和推荐（第三期）

## Decisions

### D1: LLM 服务商抽象策略

**选择:** 基于现有 LLMServiceProtocol，按服务商 API 差异分为两类实现

- **OpenAI 兼容类**（OpenAI / DeepSeek / OpenRouter / 自定义中转站）→ 复用 OpenAICompatibleService，通过 baseURL 区分
- **非 OpenAI 类**（Anthropic / Google Gemini）→ 各自独立实现

**替代方案:** 为每个服务商创建独立 Service 类 → 代码重复度高，维护成本大

**理由:** OpenAI 格式已成事实标准，大多数服务商和中转站兼容此格式。仅 Anthropic (Messages API) 和 Gemini (generateContent API) 需要独立适配。

### D2: LLMRouter 路由层

**选择:** 新增 LLMRouter 作为服务商路由器

```
ViewModel → LLMRouter.complete(model, messages)
                ↓ 根据 model.provider.providerType 路由
                ├── OpenAICompatibleService (openai/deepseek/openRouter/customOpenAI)
                ├── AnthropicService (anthropic)
                └── GeminiService (google)
```

**理由:** ViewModel 无需关心具体服务商差异，路由逻辑集中管理。

### D3: Prompt 模板变量系统

**选择:** 简单字符串替换 `{{variable}}`

支持变量: `{{title}}`, `{{abstract}}`, `{{authors}}`, `{{categories}}`, `{{full_text}}`, `{{selected_text}}`

**替代方案:** 使用模板引擎（如 Mustache）→ 过重，论文场景变量有限

**理由:** 变量集合固定且数量少（<10个），简单 `replacingOccurrences` 足够。

### D4: 论文问答上下文策略

**选择:** 根据论文长度和模型能力自动选择策略

| 条件 | 策略 |
|------|------|
| 有 Markdown + 文本 < context window 50% | 全文注入 system prompt |
| 有 Markdown + 文本 > context window 50% | 按 section 分段，关键词匹配相关段落 |
| 模型支持 pdfInput | 直接发送 PDF 文件 |
| 都没有 | PDFKit 提取纯文本（降级） |

**理由:** 兼顾质量和 token 成本，自动降级保证可用性。

### D5: SwiftData 模型升级策略

**选择:** 替换当前简化版 LLMProviderModel 为完整的 LLMProvider + LLMModel + PromptTemplate + UsageRecord 模型

**迁移:** 当前 MVP 数据量极小（个人使用），直接删除旧 model container 重建，无需渐进式迁移

### D6: 用量统计存储

**选择:** UsageRecord 存储在 SwiftData 中，每次 LLM 请求记录一条

**替代方案:** 聚合存储（按日/按模型汇总）→ 查询灵活性低

**理由:** 个人使用场景数据量可控，明细记录支持多维度分析（按模型/场景/时间）。

### D7: 卡片背面功能展示方式

**选择:** 遵循设计文档定义

| 功能 | 展示方式 |
|------|---------|
| 创新点提取 | Sheet (下滑面板) |
| 公式解析 | Sheet (下滑面板) |
| 论文问答 | NavigationStack 全屏 |
| 全文翻译 | NavigationStack 全屏 |
| 展开全文 | NavigationStack 全屏 |
| 重新生成 | 原地刷新动画 |

**理由:** Sheet 适合内容预览型功能，全屏适合需要沉浸式交互的功能。

## Risks / Trade-offs

- **[API 差异风险]** Anthropic 和 Gemini 的 API 格式与 OpenAI 差异较大（消息格式、流式响应格式等） → 实现时搜索最新 API 文档，编写独立的请求/响应序列化逻辑
- **[Token 计算不精确]** 各服务商 tokenizer 不同，本地无法精确预估 token 数 → 使用 API 返回的 usage 字段作为实际用量，预估仅用于上下文策略选择
- **[模型列表维护]** 模型列表会过时 → OpenRouter 支持动态拉取；其他服务商支持用户手动输入 model ID
- **[Prompt 模板复杂度]** 模板过多可能让用户困惑 → 内置模板标记为只读，自定义区域独立，提供"恢复默认"功能
- **[PDF 文本选中兼容性]** PDFKit 的文本选中在某些 PDF 中可能不准确 → 降级为无上下文菜单，仅保留基础阅读功能
