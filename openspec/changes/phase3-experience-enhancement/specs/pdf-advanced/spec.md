## ADDED Requirements

### Requirement: 侧边 AI 对话面板
PDF 阅读器 SHALL 支持右滑呼出侧边 AI 对话面板，实现边读 PDF 边对话。

#### Scenario: 打开侧边面板
- **WHEN** 用户在 PDF 阅读器中右滑或点击 AI 按钮
- **THEN** 系统 SHALL 从右侧滑出对话面板，宽度占屏幕 40%，PDF 内容自动缩小

#### Scenario: 侧边面板对话
- **WHEN** 用户在侧边面板中发送消息
- **THEN** 系统 SHALL 使用当前论文上下文进行 LLM 对话，支持引用 PDF 中选中的文本

### Requirement: 注释系统
PDF 阅读器 SHALL 支持高亮标注和文字注释，注释数据持久化且不修改原始 PDF。

#### Scenario: 添加高亮
- **WHEN** 用户选中 PDF 文本后点击"高亮"
- **THEN** 系统 SHALL 在选中区域添加半透明彩色覆盖层，支持选择颜色

#### Scenario: 添加文字注释
- **WHEN** 用户长按 PDF 页面某位置后选择"添加注释"
- **THEN** 系统 SHALL 在该位置放置注释图标，点击可编辑文字内容

#### Scenario: 注释列表
- **WHEN** 用户打开注释面板
- **THEN** 系统 SHALL 显示该论文所有注释和高亮，按页码排序，点击可跳转

### Requirement: 大纲导航
PDF 阅读器 SHALL 解析 PDF 目录结构，提供侧边快速跳转导航。

#### Scenario: 显示大纲
- **WHEN** 用户点击大纲按钮
- **THEN** 系统 SHALL 显示 PDF 文档目录树，层级缩进

#### Scenario: 大纲跳转
- **WHEN** 用户点击大纲中的某个章节
- **THEN** 系统 SHALL 跳转到该章节对应的 PDF 页面
