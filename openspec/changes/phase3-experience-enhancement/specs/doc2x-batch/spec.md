## ADDED Requirements

### Requirement: 批量转换
系统 SHALL 支持批量选择已下载论文提交 doc2x 转换。

#### Scenario: 批量选择转换
- **WHEN** 用户在文库页长按进入多选模式，选择多篇已下载论文后点击"批量转MD"
- **THEN** 系统 SHALL 将所有选中论文的 PDF 依次提交 doc2x 转换，显示总体进度

#### Scenario: 批量转换进度
- **WHEN** 批量转换进行中
- **THEN** 系统 SHALL 显示已完成/总数进度条，支持取消剩余转换

### Requirement: 转换用量统计
系统 SHALL 统计 doc2x 转换的页数用量。

#### Scenario: 查看转换用量
- **WHEN** 用户在 doc2x 设置页查看用量
- **THEN** 系统 SHALL 显示本月已转换页数、历史总转换页数
