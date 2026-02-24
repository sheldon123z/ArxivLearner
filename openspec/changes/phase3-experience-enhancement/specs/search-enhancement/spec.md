## ADDED Requirements

### Requirement: 搜索历史
系统 SHALL 记录用户的搜索历史，支持一键重搜。

#### Scenario: 记录搜索
- **WHEN** 用户执行搜索
- **THEN** 系统 SHALL 保存搜索关键词和筛选条件到历史记录

#### Scenario: 重搜历史
- **WHEN** 用户点击历史记录中的某条搜索
- **THEN** 系统 SHALL 恢复搜索条件并重新执行搜索

### Requirement: 推荐主题
系统 SHALL 基于用户搜索历史推荐相关研究主题。

#### Scenario: 显示推荐
- **WHEN** 用户进入搜索页且搜索框为空
- **THEN** 系统 SHALL 显示基于历史搜索的推荐主题标签

### Requirement: 保存搜索条件（订阅）
用户 SHALL 能够保存常用搜索条件作为订阅。

#### Scenario: 保存搜索
- **WHEN** 用户在搜索结果页点击"保存搜索"
- **THEN** 系统 SHALL 保存当前搜索关键词和筛选条件

#### Scenario: 管理订阅
- **WHEN** 用户查看已保存的搜索列表
- **THEN** 系统 SHALL 显示所有订阅，支持编辑、删除、一键执行

### Requirement: 定期新论文推送
系统 SHALL 通过 BGAppRefreshTask 定期检查已保存搜索的新论文，有新结果时发送本地通知。

#### Scenario: 后台检查新论文
- **WHEN** 系统后台刷新任务执行
- **THEN** 系统 SHALL 查询所有保存的搜索条件，检查是否有新论文

#### Scenario: 发送本地通知
- **WHEN** 后台检查发现新论文
- **THEN** 系统 SHALL 发送本地通知，包含新论文数量和搜索条件名称
