## 1. iCloud 同步

- [x] 1.1 配置 Xcode CloudKit capability 和 iCloud 容器
- [x] 1.2 更新 SwiftData ModelContainer 启用 CloudKit 同步
- [x] 1.3 实现 PDF 选择性同步（CKAsset 上传/下载，用户控制开关）
- [x] 1.4 实现收藏状态冲突解决（并集策略）
- [x] 1.5 创建同步状态指示器 UI（设置页显示同步状态）
- [x] 1.6 添加手动触发同步功能

## 2. 滑动浏览模式

- [x] 2.1 创建 SwipeCardView（卡片栈式布局，DragGesture 手势识别）
- [x] 2.2 实现右滑收藏手势（>100pt 阈值，收藏动画反馈）
- [x] 2.3 实现左滑跳过手势（>100pt 阈值，标记已浏览）
- [x] 2.4 实现上滑展开详情手势（>150pt 阈值，跳转完整卡片）
- [x] 2.5 创建浏览模式切换按钮（列表/滑动一键切换，SearchView 集成）
- [x] 2.6 实现已浏览论文管理（已浏览列表、30天自动清理定时任务）

## 3. 标签系统

- [x] 3.1 创建 Tag SwiftData 模型（name, color, createdAt）和 Paper-Tag 多对多关系
- [x] 3.2 创建 TagManagementView（标签列表 CRUD、颜色选择器）
- [x] 3.3 实现论文添加标签功能（标签选择弹窗，多选支持）
- [x] 3.4 实现文库页批量操作模式（长按多选、批量添加/移除标签）
- [x] 3.5 实现文库页标签筛选功能（标签芯片横向滚动，多标签组合筛选）
- [x] 3.6 实现 LLM 智能标签建议功能（基于论文内容和已有标签推荐）

## 4. 搜索增强

- [x] 4.1 创建 SearchHistory SwiftData 模型（query, filters, timestamp）
- [x] 4.2 实现搜索历史记录和展示（搜索页空状态显示历史列表、一键重搜）
- [x] 4.3 实现推荐主题功能（基于历史搜索关键词提取高频主题标签）
- [x] 4.4 创建 SavedSearch SwiftData 模型（name, query, filters, lastCheckedAt）
- [x] 4.5 实现保存搜索/订阅功能（保存当前搜索条件、管理订阅列表）
- [x] 4.6 实现 BGAppRefreshTask 后台刷新（注册后台任务、查询保存的搜索条件）
- [x] 4.7 实现新论文本地通知推送（UNUserNotificationCenter 配置、通知内容格式）

## 5. 深色模式

- [x] 5.1 扩展 AppTheme 支持 adaptive Color（所有颜色定义 light/dark 双值）
- [x] 5.2 创建外观偏好设置（跟随系统/始终浅色/始终深色，UserDefaults 持久化）
- [x] 5.3 实现应用级 ColorScheme override（在 App 根视图应用 preferredColorScheme）
- [x] 5.4 实现 PDF 阅读器独立暗色模式（CIFilter 反色处理、独立开关）

## 6. PDF 高级功能

- [x] 6.1 创建侧边 AI 对话面板（右滑呼出、宽度 40%、PDF 自适应缩小）
- [x] 6.2 实现侧边面板论文对话（复用 ChatViewModel，支持引用选中文本）
- [x] 6.3 创建 Annotation SwiftData 模型（paper 关系, type, pageIndex, rect, color, text）
- [x] 6.4 实现高亮标注功能（选中文本后添加彩色覆盖层、颜色选择）
- [x] 6.5 实现文字注释功能（长按添加注释图标、点击编辑文字）
- [x] 6.6 创建注释列表面板（按页码排序、点击跳转）
- [x] 6.7 实现 PDF 大纲解析（PDFDocument.outlineRoot 解析目录树）
- [x] 6.8 创建大纲导航侧边栏（层级缩进显示、点击跳转页面）

## 7. 阅读统计

- [x] 7.1 创建 ReadingSession SwiftData 模型（paper 关系, startTime, endTime, pagesRead）
- [x] 7.2 实现 PDF 阅读器自动记录阅读时长（进入记录 start、离开记录 end）
- [x] 7.3 创建 ReadingStatsView 主页面（热力图 + 统计摘要）
- [x] 7.4 实现日历热力图视图（Swift Charts 渲染、颜色深度映射阅读时长）
- [x] 7.5 实现周报生成（论文数、总时长、分类分布、趋势）
- [x] 7.6 实现月报生成（月度摘要、与上月对比）
- [x] 7.7 在论文详情中显示阅读统计（总时长、阅读次数）

## 8. doc2x 批量操作

- [x] 8.1 实现文库页批量转换功能（多选已下载论文、批量提交 doc2x）
- [x] 8.2 创建批量转换进度视图（已完成/总数进度条、取消按钮）
- [x] 8.3 实现转换用量统计（本月已转换页数、历史总转换页数、设置页展示）

## 9. 集成与测试

- [x] 9.1 配置 Background Modes 和 Push Notifications capability
- [x] 9.2 更新 ContentView 集成所有新视图和导航
- [x] 9.3 编写 iCloud 同步单元测试（冲突解决逻辑）
- [x] 9.4 编写标签系统单元测试（CRUD、筛选）
- [x] 9.5 编写滑动浏览手势测试
- [x] 9.6 编写搜索历史和订阅单元测试
- [x] 9.7 编写阅读统计计算单元测试
- [x] 9.8 全流程集成验证：搜索 → 滑动浏览 → 标签 → 阅读 → 统计 → 跨设备同步
