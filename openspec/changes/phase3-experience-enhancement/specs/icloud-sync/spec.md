## ADDED Requirements

### Requirement: SwiftData CloudKit 同步
系统 SHALL 通过 SwiftData + CloudKit 自动同步 Paper 元数据、收藏状态、标签、ChatMessage、PromptTemplate 到 iCloud。

#### Scenario: 跨设备数据同步
- **WHEN** 用户在设备 A 收藏一篇论文
- **THEN** 设备 B 上该论文 SHALL 自动变为已收藏状态

#### Scenario: 同步状态指示
- **WHEN** 数据正在同步中
- **THEN** 系统 SHALL 在设置页显示同步状态指示器

### Requirement: PDF 选择性同步
系统 SHALL 允许用户选择哪些已下载的 PDF 文件同步到 iCloud。

#### Scenario: 选择同步 PDF
- **WHEN** 用户在论文详情中启用"iCloud 同步"开关
- **THEN** 系统 SHALL 将该 PDF 上传到 iCloud，其他设备可下载

#### Scenario: 不同步时的行为
- **WHEN** PDF 未选择同步且用户在另一设备查看该论文
- **THEN** 系统 SHALL 显示论文元数据但标记 PDF 为"未下载"

### Requirement: Markdown 内容同步
doc2x 转换的 Markdown 内容 SHALL 随 Paper 记录自动同步。

#### Scenario: Markdown 跨设备可用
- **WHEN** 设备 A 完成 doc2x 转换
- **THEN** 设备 B 上该论文的 markdownContent SHALL 自动可用

### Requirement: 冲突解决
系统 SHALL 以最新修改时间优先解决数据冲突，收藏状态取并集。

#### Scenario: 收藏冲突
- **WHEN** 设备 A 收藏、设备 B 未收藏同一篇论文
- **THEN** 同步后该论文 SHALL 为已收藏状态（并集策略）
