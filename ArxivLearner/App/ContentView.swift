import SwiftUI

struct ContentView: View {
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

            // Chat placeholder for MVP
            NavigationStack {
                ContentUnavailableView(
                    "即将推出",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("论文对话功能将在下一版本推出")
                )
                .navigationTitle("对话")
            }
            .tabItem {
                Label("对话", systemImage: "bubble.left")
            }
            .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Paper.self, ChatMessage.self], inMemory: true)
}
