import SwiftUI

// MARK: - GlobalSystemPromptView

struct GlobalSystemPromptView: View {

    // MARK: - Persistence

    @AppStorage("global_system_prompt") private var globalSystemPrompt: String = ""

    // MARK: - State

    @State private var draftPrompt: String = ""
    @State private var showSavedToast = false
    @FocusState private var isEditorFocused: Bool

    // MARK: - Body

    var body: some View {
        Form {
            explanationSection
            editorSection
            examplesSection
        }
        .navigationTitle("全局系统指令")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    savePrompt()
                }
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.primary)
                .disabled(draftPrompt == globalSystemPrompt)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isEditorFocused = false
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .onAppear {
            draftPrompt = globalSystemPrompt
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                savedToast
            }
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.primary)
                    .padding(.top, 1)
                Text("此指令将注入所有 LLM 请求的系统提示中，优先级最低，可被场景模板覆盖。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        Section {
            TextEditor(text: $draftPrompt)
                .frame(minHeight: 180)
                .focused($isEditorFocused)
                .font(.system(.body, design: .monospaced))

            if !draftPrompt.isEmpty {
                HStack {
                    Spacer()
                    Text("\(draftPrompt.count) 字符")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        } header: {
            Text("系统指令内容")
        } footer: {
            Text("留空则不注入全局系统指令")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Examples Section

    private var examplesSection: some View {
        Section("示例指令") {
            ExamplePromptRow(
                title: "中文回复",
                description: "强制所有响应使用中文",
                prompt: "请始终使用中文回复，无论用户以何种语言提问。"
            ) { prompt in
                appendToPrompt(prompt)
            }

            ExamplePromptRow(
                title: "专业学术风格",
                description: "保持严谨学术写作风格",
                prompt: "你是一位专业的学术研究助手，回答应严谨、准确，引用相关领域术语，避免口语化表达。"
            ) { prompt in
                appendToPrompt(prompt)
            }

            ExamplePromptRow(
                title: "简洁输出",
                description: "要求输出简洁不冗余",
                prompt: "回答应简洁明了，避免不必要的重复和冗余内容，直接给出关键信息。"
            ) { prompt in
                appendToPrompt(prompt)
            }
        }
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("已保存")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 4)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func savePrompt() {
        globalSystemPrompt = draftPrompt
        isEditorFocused = false
        withAnimation(.spring(duration: 0.3)) {
            showSavedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSavedToast = false
                }
            }
        }
    }

    private func appendToPrompt(_ text: String) {
        if draftPrompt.isEmpty {
            draftPrompt = text
        } else {
            draftPrompt += "\n" + text
        }
    }
}

// MARK: - ExamplePromptRow

private struct ExamplePromptRow: View {

    let title: String
    let description: String
    let prompt: String
    let onAppend: (String) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button {
                onAppend(prompt)
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(AppTheme.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        GlobalSystemPromptView()
    }
}
