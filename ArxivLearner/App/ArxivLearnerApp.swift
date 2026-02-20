import SwiftUI
import SwiftData

@main
struct ArxivLearnerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Paper.self, ChatMessage.self])
    }
}
