import SwiftUI
import SwiftData

// MARK: - ChatView

/// Full-screen chat interface for discussing a specific paper with an LLM.
struct ChatView: View {

    let paper: Paper

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
            .background(AppTheme.background)
            .navigationTitle(paper.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onAppear {
            viewModel.loadMessages(for: paper, context: modelContext)
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 240)
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.spacing) {
                    if viewModel.messages.isEmpty && !viewModel.isGenerating {
                        emptyStateView
                            .padding(.top, 60)
                    }

                    ForEach(viewModel.messages, id: \.persistentModelID) { message in
                        MessageBubble(message: message)
                            .id(message.persistentModelID)
                    }

                    // Anchor for auto-scroll.
                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(.horizontal)
                .padding(.vertical, AppTheme.spacing)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.last?.content) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))

            Text("开始与论文对话")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("提问关于这篇论文的任何问题")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacing) {
            // Multi-line text field
            TextField("输入问题...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                .disabled(viewModel.isGenerating)

            // Send / Stop button
            if viewModel.isGenerating {
                stopButton
            } else {
                sendButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(AppTheme.background)
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendMessage(context: modelContext) }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AppTheme.textSecondary.opacity(0.4)
                        : AppTheme.primary
                )
        }
        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .animation(.easeInOut(duration: 0.15), value: viewModel.inputText.isEmpty)
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button {
            viewModel.stopGeneration()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.accent)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - MessageBubble

/// A single chat message displayed as a rounded bubble.
struct MessageBubble: View {

    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? " " : message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : AppTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? AppTheme.primary : AppTheme.cardBackground,
                        in: bubbleShape(isUser: isUser)
                    )

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }

    // MARK: - Bubble Shape

    private func bubbleShape(isUser: Bool) -> some Shape {
        // Slightly different radii on the "tail" corner to simulate speech-bubble feel.
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: isUser ? 16 : 4,
            bottomTrailingRadius: isUser ? 4 : 16,
            topTrailingRadius: 16
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Paper.self, ChatMessage.self, configurations: config)

    let paper = Paper(
        arxivId: "2401.00001",
        title: "Attention Is All You Need: A Comprehensive Review of Transformer Architectures",
        authors: ["Vaswani, A.", "Shazeer, N."],
        abstractText: "We propose a new simple network architecture, the Transformer, based solely on attention mechanisms.",
        categories: ["cs.LG", "cs.CL"]
    )
    container.mainContext.insert(paper)

    let msg1 = ChatMessage(paper: paper, role: "user", content: "这篇论文的核心贡献是什么？", timestamp: .now)
    let msg2 = ChatMessage(paper: paper, role: "assistant", content: "该论文的核心贡献是提出了完全基于注意力机制的 Transformer 架构，彻底摒弃了循环网络和卷积网络。", timestamp: .now)
    container.mainContext.insert(msg1)
    container.mainContext.insert(msg2)

    return ChatView(paper: paper)
        .modelContainer(container)
}
