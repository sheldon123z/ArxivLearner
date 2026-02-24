## ADDED Requirements

### Requirement: 阅读时长追踪
系统 SHALL 自动追踪用户阅读每篇论文的时长，以 ReadingSession 为单位记录。

#### Scenario: 自动记录阅读时长
- **WHEN** 用户进入 PDF 阅读器
- **THEN** 系统 SHALL 记录开始时间，离开时记录结束时间和已读页数，创建 ReadingSession

#### Scenario: 查看论文阅读时长
- **WHEN** 用户在论文详情中查看阅读统计
- **THEN** 系统 SHALL 显示该论文的总阅读时长和阅读次数

### Requirement: 日历热力图
系统 SHALL 提供日历视图展示每日阅读量。

#### Scenario: 查看热力图
- **WHEN** 用户进入"阅读统计"页面
- **THEN** 系统 SHALL 显示日历热力图，颜色深度表示当日阅读时长，类似 GitHub 贡献图

### Requirement: 周报/月报自动生成
系统 SHALL 支持自动生成阅读周报和月报。

#### Scenario: 查看周报
- **WHEN** 用户点击"本周报告"
- **THEN** 系统 SHALL 显示本周阅读的论文数量、总时长、最常阅读的分类、阅读趋势

#### Scenario: 查看月报
- **WHEN** 用户点击"本月报告"
- **THEN** 系统 SHALL 显示本月阅读统计摘要，包含论文数、时长、分类分布、与上月对比
