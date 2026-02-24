## ADDED Requirements

### Requirement: 选中文本上下文菜单
PDF 阅读器 SHALL 支持选中文本后显示自定义上下文菜单，提供复制、翻译、解释、提问四个操作。

#### Scenario: 选中文本并翻译
- **WHEN** 用户在 PDF 阅读器中选中一段文本并点击"翻译"
- **THEN** 系统 SHALL 调用 LLM 翻译选中文本，在浮动面板中显示结果

#### Scenario: 选中文本并解释
- **WHEN** 用户选中文本并点击"解释"
- **THEN** 系统 SHALL 调用 LLM 对选中文本进行通俗解释，在浮动面板中显示

#### Scenario: 选中文本并提问
- **WHEN** 用户选中文本并点击"提问"
- **THEN** 系统 SHALL 将选中文本作为上下文跳转到论文问答页面，自动填入 `{{selected_text}}`

#### Scenario: 复制文本
- **WHEN** 用户选中文本并点击"复制"
- **THEN** 系统 SHALL 将选中文本复制到系统剪贴板

### Requirement: PDF 书签管理
PDF 阅读器 SHALL 支持在当前页面添加书签，书签持久化存储。

#### Scenario: 添加书签
- **WHEN** 用户在 PDF 阅读器中点击"添加书签"
- **THEN** 系统 SHALL 记录当前页码和可选备注，持久化到 Paper 模型

#### Scenario: 查看书签列表
- **WHEN** 用户点击书签列表按钮
- **THEN** 系统 SHALL 显示该论文所有书签，点击可跳转到对应页面

#### Scenario: 删除书签
- **WHEN** 用户在书签列表中滑动删除某个书签
- **THEN** 系统 SHALL 从持久化存储中移除该书签
