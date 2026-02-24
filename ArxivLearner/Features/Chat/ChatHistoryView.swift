import SwiftUI
import SwiftData

// MARK: - ChatHistoryView

/// Lists all papers that have at least one chat message, sorted by most recent activity.
/// This view replaces the placeholder in the "对话" tab.
struct ChatHistoryView: View {

    // Fetch all papers; we filter in-memory for those with chat messages.
    // SwiftData @Query does not support `!chatMessages.isEmpty` in a predicate, so we
    // fetch everything and filter on the computed property.
    @Query(sort: \Paper.createdAt, order: .reverse) private var allPapers: [Paper]

    @State private var searchText: String = ""
    @State private var selectedPaper: Paper?
    @State private var showChat: Bool = false

    // MARK: - Derived Data

    private var papersWithChats: [Paper] {
        allPapers.filter { !$0.chatMessages.isEmpty }
    }

    private var filteredPapers: [Paper] {
        let sorted = papersWithChats.sorted { a, b in
            let aLast = a.chatMessages.map(\.timestamp).max() ?? a.createdAt
            let bLast = b.chatMessages.map(\.timestamp).max() ?? b.createdAt
            return aLast > bLast
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return sorted
        }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.title.lowercased().contains(query) ||
            $0.authors.joined(separator: " ").lowercased().contains(query)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if papersWithChats.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("对话")
            .searchable(text: $searchText, prompt: "搜索论文对话...")
            .background(AppTheme.background)
            .navigationDestination(isPresented: $showChat) {
                if let paper = selectedPaper {
                    ChatView(paper: paper)
                }
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(filteredPapers, id: \.arxivId) { paper in
                ChatHistoryRow(paper: paper)
                    .listRowBackground(AppTheme.background)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPaper = paper
                        showChat = true
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.spacing) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))

            Text("还没有对话记录")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("从文库或搜索结果中打开一篇论文，\n点击「问答」开始对话")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ChatHistoryRow

/// A single row in the chat history list showing the paper title, last message preview,
/// and the timestamp of the most recent message.
struct ChatHistoryRow: View {

    let paper: Paper

    // MARK: - Computed Helpers

    private var sortedMessages: [ChatMessage] {
        paper.chatMessages.sorted { $0.timestamp < $1.timestamp }
    }

    private var lastMessage: ChatMessage? {
        sortedMessages.last
    }

    private var lastTimestamp: Date {
        lastMessage?.timestamp ?? paper.createdAt
    }

    private var messageCount: Int {
        paper.chatMessages.count
    }

    private var previewText: String {
        guard let last = lastMessage else { return "暂无消息" }
        let prefix = last.role == "user" ? "你: " : "助手: "
        let content = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = content.count > 80 ? String(content.prefix(80)) + "..." : content
        return prefix + truncated
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing) {
            // Left icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.primary)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(paper.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Timestamp
                    Text(relativeTimestamp)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.leading, 8)
                        .fixedSize()
                }

                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                // Message count badge
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    Text("\(messageCount) 条消息")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Relative Timestamp

    private var relativeTimestamp: String {
        let now = Date.now
        let diff = now.timeIntervalSince(lastTimestamp)

        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes) 分钟前"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours) 小时前"
        } else if diff < 86400 * 7 {
            let days = Int(diff / 86400)
            return "\(days) 天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: lastTimestamp)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Paper.self, ChatMessage.self, configurations: config)
    let ctx = container.mainContext

    let p1 = Paper(
        arxivId: "2401.00001",
        title: "Attention Is All You Need",
        authors: ["Vaswani et al."],
        abstractText: "We propose the Transformer.",
        categories: ["cs.LG"]
    )
    let p2 = Paper(
        arxivId: "2401.00002",
        title: "BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding",
        authors: ["Devlin et al."],
        abstractText: "We introduce BERT.",
        categories: ["cs.CL"]
    )
    ctx.insert(p1)
    ctx.insert(p2)

    ctx.insert(ChatMessage(paper: p1, role: "user", content: "核心贡献是什么？", timestamp: .now.addingTimeInterval(-300)))
    ctx.insert(ChatMessage(paper: p1, role: "assistant", content: "提出了 Transformer 架构。", timestamp: .now.addingTimeInterval(-250)))
    ctx.insert(ChatMessage(paper: p2, role: "user", content: "BERT 和 GPT 有什么区别？", timestamp: .now.addingTimeInterval(-3600)))

    return ChatHistoryView()
        .modelContainer(container)
}
