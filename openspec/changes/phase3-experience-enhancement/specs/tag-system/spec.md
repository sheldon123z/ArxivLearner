## ADDED Requirements

### Requirement: 自定义标签创建
用户 SHALL 能够创建自定义标签，每个标签包含名称和颜色。

#### Scenario: 创建标签
- **WHEN** 用户在标签管理中点击"新建标签"并输入名称、选择颜色
- **THEN** 系统 SHALL 创建新标签并持久化存储

#### Scenario: 为论文添加标签
- **WHEN** 用户在论文卡片上点击"添加标签"
- **THEN** 系统 SHALL 显示标签选择列表，支持多选

### Requirement: 批量标签操作
系统 SHALL 支持长按多选论文后批量添加/移除标签。

#### Scenario: 批量添加标签
- **WHEN** 用户长按进入多选模式，选择多篇论文后点击"添加标签"
- **THEN** 系统 SHALL 为所有选中论文添加指定标签

#### Scenario: 批量移除标签
- **WHEN** 用户在多选模式中选择"移除标签"
- **THEN** 系统 SHALL 从选中论文中移除指定标签

### Requirement: 标签筛选
文库页 SHALL 支持按标签筛选论文。

#### Scenario: 按标签筛选
- **WHEN** 用户在文库页选择一个或多个标签进行筛选
- **THEN** 系统 SHALL 仅显示包含所选标签的论文

### Requirement: LLM 智能标签建议
系统 SHALL 支持通过 LLM 基于论文内容建议合适的标签。

#### Scenario: 获取标签建议
- **WHEN** 用户为论文添加标签时点击"智能建议"
- **THEN** 系统 SHALL 基于论文标题和摘要，结合用户已有标签列表，推荐 3-5 个标签
