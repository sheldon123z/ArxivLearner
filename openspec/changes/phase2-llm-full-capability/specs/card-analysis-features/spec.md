## ADDED Requirements

### Requirement: 创新点提取
系统 SHALL 支持通过 LLM 分析论文的创新点（novelty），使用 innovationExtract 场景模板。

#### Scenario: 触发创新点提取
- **WHEN** 用户在卡片背面点击"创新点提取"按钮
- **THEN** 系统 SHALL 打开下滑面板（Sheet），调用 LLM 生成创新点列表，按重要性排列，流式显示

#### Scenario: 缓存创新点结果
- **WHEN** 创新点提取完成
- **THEN** 系统 SHALL 缓存结果，再次打开时直接显示缓存内容，提供"重新生成"按钮

### Requirement: 公式解析
系统 SHALL 支持通过 LLM 提取并通俗解释论文中的关键公式，使用 formulaAnalysis 场景模板。

#### Scenario: 触发公式解析
- **WHEN** 用户在卡片背面点击"公式解析"按钮
- **THEN** 系统 SHALL 打开下滑面板（Sheet），调用 LLM 提取关键公式并给出通俗解释，流式显示

#### Scenario: 基于 Markdown 中的 LaTeX 公式
- **WHEN** 论文已有 doc2x 转换的 Markdown 内容
- **THEN** 系统 SHALL 优先使用 Markdown 中的 LaTeX 公式块作为分析输入

### Requirement: 全文翻译
系统 SHALL 支持论文全文逐段翻译，原文与译文对照显示，使用 translation 场景模板。

#### Scenario: 触发全文翻译
- **WHEN** 用户在卡片背面点击"全文翻译"按钮
- **THEN** 系统 SHALL 打开全屏页面，逐段发送论文内容给 LLM 进行翻译

#### Scenario: 原文/译文对照显示
- **WHEN** 翻译结果返回
- **THEN** 系统 SHALL 以原文段落和译文段落交替或左右对照的方式显示

#### Scenario: 翻译进度
- **WHEN** 翻译进行中
- **THEN** 系统 SHALL 显示当前翻译进度（已翻译段数/总段数）

### Requirement: 展开全文详情
系统 SHALL 支持在全屏页面展示论文完整信息，包括元数据、完整摘要、Markdown 全文（如有）、PDF 入口。

#### Scenario: 打开全文详情
- **WHEN** 用户在卡片背面点击"展开全文详情"按钮
- **THEN** 系统 SHALL 打开全屏页面，显示完整论文信息和 Markdown 渲染内容

### Requirement: 重新生成见解
系统 SHALL 支持重新生成卡片背面的核心见解，支持切换模型后重新生成。

#### Scenario: 重新生成
- **WHEN** 用户在卡片背面点击"重新生成"按钮
- **THEN** 系统 SHALL 使用当前选择的模型重新调用 insightGeneration 模板，原地刷新见解内容

#### Scenario: 切换模型后重新生成
- **WHEN** 用户在重新生成前切换了默认见解模型
- **THEN** 系统 SHALL 使用新模型生成见解，替换旧内容
