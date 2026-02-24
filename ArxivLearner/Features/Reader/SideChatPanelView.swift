import SwiftUI
import SwiftData

// MARK: - SideChatPanelView

/// Compact chat panel embedded in the PDF reader side panel.
struct SideChatPanelView: View {
    let paper: Paper
    @Binding var quotedText: String

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @State private var didInjectQuote = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(AppTheme.primary)
                Text("AI 对话")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)

            Divider()

            // Message list
            messageList

            Divider()

            // Input bar
            inputBar
        }
        .background(AppTheme.background)
        .onAppear {
            viewModel.loadMessages(for: paper, context: modelContext)
        }
        .onChange(of: quotedText) { _, newValue in
            guard !newValue.isEmpty else { return }
            let blockquote = "> \(newValue)\n\n"
            if viewModel.inputText.isEmpty {
                viewModel.inputText = blockquote
            } else {
                viewModel.inputText = blockquote + viewModel.inputText
            }
            quotedText = ""
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty && !viewModel.isGenerating {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                            Text("向 AI 提问关于这篇论文的问题")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.messages, id: \.persistentModelID) { message in
                        CompactMessageBubble(message: message)
                            .id(message.persistentModelID)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: viewModel.messages.last?.content) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入问题...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                .disabled(viewModel.isGenerating)

            if viewModel.isGenerating {
                Button { viewModel.stopGeneration() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppTheme.accent)
                }
            } else {
                Button {
                    Task { await viewModel.sendMessage(context: modelContext) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppTheme.textSecondary.opacity(0.4)
                                : AppTheme.primary
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.background)
    }
}

// MARK: - CompactMessageBubble

private struct CompactMessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if isUser { Spacer(minLength: 20) }

            Text(message.content.isEmpty ? " " : message.content)
                .font(.caption)
                .foregroundStyle(isUser ? .white : AppTheme.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isUser ? AppTheme.primary : AppTheme.cardBackground,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: isUser ? 12 : 3,
                        bottomTrailingRadius: isUser ? 3 : 12,
                        topTrailingRadius: 12
                    )
                )

            if !isUser { Spacer(minLength: 20) }
        }
    }
}
