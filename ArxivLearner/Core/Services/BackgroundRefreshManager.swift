import Foundation
import BackgroundTasks
import SwiftData

// MARK: - BackgroundRefreshManager

final class BackgroundRefreshManager: @unchecked Sendable {

    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.arxivlearner.refresh"

    private let apiService = ArxivAPIService()

    private init() {}

    // MARK: - Registration

    /// 注册后台刷新任务（在 App 启动时调用）
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundRefresh(task: refreshTask)
        }
    }

    // MARK: - Scheduling

    /// 调度下次后台刷新
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1小时后

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundRefreshManager] 调度后台任务失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let taskHandle = Task {
            await performRefresh(modelContext: nil)
        }

        task.expirationHandler = {
            taskHandle.cancel()
        }

        Task {
            _ = await taskHandle.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Refresh Logic

    /// 执行刷新。传入 modelContext 时使用现有上下文，否则创建新的 ModelContainer。
    @MainActor
    func performRefresh(modelContext: ModelContext?) async {
        let context: ModelContext

        if let provided = modelContext {
            context = provided
        } else {
            guard let container = try? ModelContainer(
                for: SavedSearch.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            ) else {
                return
            }
            context = container.mainContext
        }

        let descriptor = FetchDescriptor<SavedSearch>(
            predicate: #Predicate { $0.isEnabled == true }
        )

        guard let savedSearches = try? context.fetch(descriptor) else { return }

        for saved in savedSearches {
            await refreshSavedSearch(saved, context: context)
        }
    }

    @MainActor
    private func refreshSavedSearch(_ saved: SavedSearch, context: ModelContext) async {
        let params = ArxivSearchParams(
            query: saved.query,
            category: saved.filterCategory,
            maxResults: 20
        )

        do {
            let results = try await apiService.search(params: params)
            let newCount = results.count
            let previousCount = saved.lastResultCount

            if newCount > previousCount && previousCount > 0 {
                let diff = newCount - previousCount
                NotificationManager.shared.sendNewPapersNotification(
                    searchName: saved.name,
                    newCount: diff
                )
            }

            saved.lastCheckedAt = .now
            saved.lastResultCount = newCount
            try? context.save()
        } catch {
            print("[BackgroundRefreshManager] 刷新搜索 '\(saved.name)' 失败: \(error.localizedDescription)")
        }
    }
}
