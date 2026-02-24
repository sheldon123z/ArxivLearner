import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct ArxivLearnerApp: App {

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Paper.self,
            ChatMessage.self,
            LLMProvider.self,
            LLMModel.self,
            PromptTemplate.self,
            UsageRecord.self,
            Tag.self,
            SearchHistory.self,
            SavedSearch.self,
            Annotation.self,
            ReadingSession.self,
        ])
        // Use CloudKit-backed store when iCloud is available
        if FileManager.default.ubiquityIdentityToken != nil {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.arxivlearner.app")
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
                return container
            }
        }
        // Fall back to local-only store
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [localConfig])
    }()

    init() {
        BackgroundRefreshManager.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
