## Why

第二期完成后，ArxivLearner 已具备完整的多模型 LLM 能力。但作为日常论文阅读工具，仍缺少多设备同步、高效浏览模式、个性化标签管理、搜索增强等体验层功能。第三期目标是将应用从"可用"提升到"好用"，打造流畅的日常论文阅读体验。

## What Changes

- 新增 iCloud 同步：SwiftData + CloudKit 跨设备同步元数据、收藏、标签、Prompt 模板，PDF 选择性同步
- 新增滑动浏览模式：类 Tinder 左右滑动卡片，右滑收藏/左滑跳过/上滑展开，与列表模式一键切换
- 新增标签系统：自定义标签（名称+颜色）、批量操作、标签筛选、LLM 智能标签建议
- 新增搜索增强：搜索历史记录、推荐主题、保存搜索条件（订阅）、后台定期检查新论文推送
- 新增深色模式支持：跟随系统/手动切换、PDF 阅读器独立暗色模式
- 新增 PDF 高级功能：侧边 AI 面板（边读边对话）、注释系统（高亮+文字注释）、大纲导航
- 新增阅读统计：每篇论文阅读时长、日历热力图、周报/月报自动生成
- 新增 doc2x 批量转换和转换用量统计

## Capabilities

### New Capabilities
- `icloud-sync`: iCloud 同步，SwiftData + CloudKit 跨设备同步，PDF 选择性同步，冲突解决策略
- `swipe-browsing`: 滑动浏览模式，类 Tinder 卡片交互，手势操作（右滑收藏/左滑跳过/上滑展开），列表/滑动模式切换，已浏览管理
- `tag-system`: 标签管理系统，自定义标签创建（名称+颜色）、批量操作、文库标签筛选、LLM 智能标签建议
- `search-enhancement`: 搜索增强，搜索历史、推荐主题、保存搜索条件（订阅）、BGAppRefreshTask 定期检查+本地通知
- `dark-mode`: 深色模式支持，跟随系统/手动切换、PDF 阅读器独立暗色模式
- `pdf-advanced`: PDF 高级功能，侧边 AI 对话面板、高亮注释系统、大纲导航
- `reading-statistics`: 阅读统计，论文阅读时长追踪、日历热力图视图、自动生成周报/月报
- `doc2x-batch`: doc2x 批量操作，批量选择论文提交转换、转换用量统计

### Modified Capabilities
（无已有 specs 需要修改）

## Impact

- **App/ArxivLearnerApp.swift**: 添加 CloudKit 容器配置、BGAppRefreshTask 注册
- **Core/Storage/**: SwiftData 模型添加 CloudKit 同步支持，新增 Tag 模型、ReadingSession 模型
- **Features/Search/**: 搜索历史、推荐、订阅功能扩展
- **Features/Cards/**: 新增滑动浏览模式（SwipeCardView）、标签显示
- **Features/Library/**: 标签筛选、批量操作
- **Features/Reader/**: 侧边 AI 面板、注释系统、大纲导航
- **Features/Settings/**: 深色模式设置、iCloud 同步设置
- **Shared/Theme/**: 深色模式主题支持
- **项目配置**: 启用 CloudKit capability、Push Notifications capability、Background Modes capability
