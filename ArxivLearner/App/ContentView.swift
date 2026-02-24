import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("发现", systemImage: "magnifyingglass")
                }
                .tag(0)

            LibraryView()
                .tabItem {
                    Label("文库", systemImage: "books.vertical")
                }
                .tag(1)

            ChatHistoryView()
                .tabItem {
                    Label("对话", systemImage: "bubble.left")
                }
                .tag(2)

            ReadingStatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(AppTheme.primary)
        .preferredColorScheme(AppearanceManager.shared.colorScheme)
        .onAppear {
            DefaultPromptsLoader.loadIfNeeded(context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
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
        ], inMemory: true)
}
