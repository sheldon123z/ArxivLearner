import SwiftUI
import SwiftData

// Temporary placeholder - will be replaced by Task 13
struct FullCardView: View {
    let paper: ArxivPaperDTO
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Full Card View - Coming Soon")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}
