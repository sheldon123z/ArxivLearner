## ADDED Requirements

### Requirement: 滑动浏览模式
系统 SHALL 提供类 Tinder 的卡片滑动浏览模式，用户一次聚焦一张完整卡片。

#### Scenario: 右滑收藏
- **WHEN** 用户在滑动浏览模式中将卡片向右拖拽超过 100pt
- **THEN** 系统 SHALL 收藏该论文并显示下一张卡片

#### Scenario: 左滑跳过
- **WHEN** 用户将卡片向左拖拽超过 100pt
- **THEN** 系统 SHALL 将论文标记为"已浏览"并显示下一张卡片

#### Scenario: 上滑展开详情
- **WHEN** 用户将卡片向上拖拽超过 150pt
- **THEN** 系统 SHALL 展开论文完整卡片详情

### Requirement: 浏览模式切换
系统 SHALL 支持列表模式和滑动模式的一键切换。

#### Scenario: 切换模式
- **WHEN** 用户点击搜索结果页的模式切换按钮
- **THEN** 系统 SHALL 在列表视图和滑动视图之间切换，保持当前数据

### Requirement: 已浏览管理
左滑跳过的论文 SHALL 进入"已浏览"列表，30 天后自动清理。

#### Scenario: 查看已浏览
- **WHEN** 用户在文库页切换到"已浏览"筛选
- **THEN** 系统 SHALL 显示所有跳过的论文

#### Scenario: 自动清理
- **WHEN** 某篇已浏览论文超过 30 天
- **THEN** 系统 SHALL 自动从已浏览列表移除
