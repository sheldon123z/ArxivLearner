## Context

第二期完成后，ArxivLearner 已具备多模型 LLM 全能力、完整的 Prompt 模板体系、论文问答、卡片分析功能集和用量统计。第三期聚焦体验增强，将应用从功能完备提升到日常好用。

## Goals / Non-Goals

**Goals:**
- 实现 iCloud 跨设备同步，保证数据不丢失
- 提供高效的滑动浏览模式，降低论文筛选成本
- 构建灵活的标签管理系统
- 增强搜索体验，支持订阅和推送
- 完善深色模式和 PDF 高级阅读功能
- 提供阅读数据可视化

**Non-Goals:**
- 社交分享功能
- 多用户协作
- Web 端或 Android 端
- 自建后端服务

## Decisions

### D1: iCloud 同步策略

**选择:** SwiftData + CloudKit 自动同步

- Paper 元数据、收藏状态、标签、Prompt 模板通过 SwiftData 的 CloudKit 集成自动同步
- PDF 文件通过 FileManager + CloudKit CKAsset 选择性同步（用户手动选择哪些 PDF 同步）
- Markdown 文件随 Paper 记录自动同步

**冲突解决:** 最新修改时间优先，收藏状态取并集（任一设备收藏即为收藏）

**替代方案:** 自建同步服务 → 维护成本高，个人使用场景不值得

### D2: 滑动浏览实现

**选择:** 自定义 SwiftUI 手势系统

- 使用 DragGesture 实现左右滑动卡片
- 卡片栈式布局（当前卡片 + 后方预览）
- 阈值判定：水平拖拽 > 100pt 触发收藏/跳过，垂直上拖 > 150pt 触发展开
- 已跳过论文进入"已浏览"列表，30 天后自动清理

**替代方案:** TabView + .page style → 不支持自定义手势操作

### D3: 后台刷新与推送

**选择:** BGAppRefreshTask + UNUserNotificationCenter 本地通知

- 使用 BGAppRefreshTask 注册后台刷新任务
- 按用户保存的搜索条件查询 arXiv API
- 有新论文时发送本地通知
- 刷新频率由系统调度（通常每天 1-2 次）

**理由:** 无需自建推送服务，iOS 原生后台刷新机制足够满足论文更新频率。

### D4: PDF 注释存储

**选择:** 将注释数据存储在 SwiftData 中，与 Paper 模型关联

- 注释类型：高亮（页码+位置+颜色）、文字注释（页码+位置+文本）
- 不修改原始 PDF 文件，注释作为覆盖层渲染
- 支持 iCloud 同步

**替代方案:** 直接写入 PDF → 会修改原文件，不利于同步和版本管理

### D5: 阅读统计采集

**选择:** 自动追踪 + 最小化侵入

- 进入 PDF 阅读器时记录 startTime，离开时记录 endTime，自动计算阅读时长
- 使用 ReadingSession 模型（paper 关系, startTime, endTime, pagesRead）
- 热力图使用 Swift Charts 渲染日历视图

### D6: 深色模式实现

**选择:** SwiftUI 原生 ColorScheme + 自定义偏好

- 三种模式：跟随系统（默认）、始终浅色、始终深色
- AppTheme 中所有颜色使用 adaptive Color（light/dark 双值）
- PDF 阅读器独立暗色模式：通过 CIFilter 反色处理 PDF 渲染

## Risks / Trade-offs

- **[CloudKit 同步延迟]** iCloud 同步可能有延迟 → 提供同步状态指示器，允许手动触发同步
- **[后台刷新不可靠]** iOS 后台刷新频率由系统控制 → 用户可手动进入应用检查新论文
- **[PDF 注释性能]** 大量注释可能影响 PDF 渲染性能 → 使用懒加载，只渲染当前可见页面的注释
- **[滑动浏览数据消耗]** 快速滑动可能触发大量摘要显示 → 使用已缓存的搜索结果，不额外请求
- **[热力图数据量]** 长期使用后 ReadingSession 数据量增长 → 定期聚合历史数据，保留最近 365 天明细
