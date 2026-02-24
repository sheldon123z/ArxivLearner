import SwiftUI
import SwiftData

// MARK: - PromptEditorView

struct PromptEditorView: View {

    // MARK: - Query

    @Query(sort: \PromptTemplate.sortOrder, order: .forward)
    private var templates: [PromptTemplate]

    // MARK: - State

    @State private var selectedTemplate: PromptTemplate? = nil
    @State private var showEditor = false

    // MARK: - Grouped Templates

    private var groupedTemplates: [(scene: PromptScene, templates: [PromptTemplate])] {
        let scenes = PromptScene.allCases
        return scenes.compactMap { scene in
            let group = templates.filter { $0.scene == scene }
            return group.isEmpty ? nil : (scene: scene, templates: group)
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            if templates.isEmpty {
                emptyState
            } else {
                ForEach(groupedTemplates, id: \.scene) { group in
                    Section(group.scene.displayName) {
                        ForEach(group.templates) { template in
                            TemplateRow(template: template)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTemplate = template
                                    showEditor = true
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Prompt 模板")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditor) {
            if let template = selectedTemplate {
                PromptTemplateEditorSheet(template: template)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: AppTheme.spacing) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("暂无 Prompt 模板")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("模板将在首次使用时自动创建")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
}

// MARK: - TemplateRow

private struct TemplateRow: View {

    let template: PromptTemplate

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if template.isBuiltIn {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(template.name)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text(template.scene.displayName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text(template.format.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.secondary.opacity(0.15))
                    .foregroundStyle(AppTheme.secondary)
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PromptTemplateEditorSheet

struct PromptTemplateEditorSheet: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    let template: PromptTemplate

    // MARK: - State

    @State private var systemPrompt: String = ""
    @State private var userPromptTemplate: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 2000
    @State private var responseLanguage: String = "zh-CN"
    @State private var outputFormat: OutputFormat = .markdown

    @State private var showPreview = false
    @State private var showResetConfirm = false
    @State private var hasUnsavedChanges = false

    // MARK: - Language Options

    private let languageOptions: [(label: String, value: String)] = [
        ("中文", "zh-CN"),
        ("英文", "en-US"),
        ("日文", "ja-JP"),
        ("德文", "de-DE"),
        ("法文", "fr-FR"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                promptsSection
                parametersSection
                actionsSection
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveTemplate() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .sheet(isPresented: $showPreview) {
                PromptPreviewSheet(
                    systemPrompt: systemPrompt,
                    userPromptTemplate: userPromptTemplate
                )
            }
            .alert("恢复默认", isPresented: $showResetConfirm) {
                Button("恢复", role: .destructive) { resetToBuiltIn() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将丢弃所有自定义修改并恢复此模板的内置默认内容")
            }
            .onAppear { loadValues() }
        }
    }

    // MARK: - Prompts Section

    private var promptsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("系统提示词", systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 100)
                    .disabled(template.isBuiltIn)
                    .opacity(template.isBuiltIn ? 0.6 : 1.0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("用户提示词模板", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                TextEditor(text: $userPromptTemplate)
                    .frame(minHeight: 120)
                    .disabled(template.isBuiltIn)
                    .opacity(template.isBuiltIn ? 0.6 : 1.0)
            }

            if template.isBuiltIn {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("内置模板不可编辑提示词内容")
                        .font(.caption)
                }
                .foregroundStyle(AppTheme.textSecondary)
            } else {
                variablesHint
            }
        } header: {
            Text("提示词内容")
        }
    }

    // MARK: - Variables Hint

    private var variablesHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("支持的变量:")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.textSecondary)
            let vars = ["{{title}}", "{{authors}}", "{{categories}}", "{{abstract}}", "{{full_text}}"]
            FlowLayout(spacing: 4) {
                ForEach(vars, id: \.self) { variable in
                    Text(variable)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.primary.opacity(0.1))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Parameters Section

    private var parametersSection: some View {
        Section("参数") {
            HStack {
                Text("语言")
                Spacer()
                Picker("语言", selection: $responseLanguage) {
                    ForEach(languageOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AppTheme.primary)
            }

            HStack {
                Text("输出格式")
                Spacer()
                Picker("输出格式", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("温度")
                    Spacer()
                    Text(String(format: "%.1f", temperature))
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                }
                Slider(value: $temperature, in: 0...2, step: 0.1)
                    .tint(AppTheme.primary)
            }

            Stepper {
                HStack {
                    Text("最大 Token 数")
                    Spacer()
                    Text("\(maxTokens)")
                        .foregroundStyle(AppTheme.textSecondary)
                        .monospacedDigit()
                }
            } onIncrement: {
                maxTokens = min(maxTokens + 500, 32_000)
            } onDecrement: {
                maxTokens = max(maxTokens - 500, 500)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                showPreview = true
            } label: {
                Label("预览测试", systemImage: "eye")
                    .foregroundStyle(AppTheme.primary)
            }

            if template.isBuiltIn {
                Button {
                    showResetConfirm = true
                } label: {
                    Label("恢复默认", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Load Values

    private func loadValues() {
        systemPrompt = template.systemPrompt
        userPromptTemplate = template.userPromptTemplate
        temperature = template.temperature
        maxTokens = template.maxTokens
        responseLanguage = template.responseLanguage
        outputFormat = template.format
    }

    // MARK: - Save

    private func saveTemplate() {
        if !template.isBuiltIn {
            template.systemPrompt = systemPrompt
            template.userPromptTemplate = userPromptTemplate
        }
        template.temperature = temperature
        template.maxTokens = maxTokens
        template.responseLanguage = responseLanguage
        template.format = outputFormat
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Reset

    private func resetToBuiltIn() {
        // Restore only the editable parameters; prompts remain locked for built-in
        temperature = 0.7
        maxTokens = 2000
        responseLanguage = "zh-CN"
        outputFormat = .markdown
    }
}

// MARK: - PromptPreviewSheet

private struct PromptPreviewSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Query private var papers: [Paper]

    let systemPrompt: String
    let userPromptTemplate: String

    @State private var selectedPaperIndex: Int = 0
    @State private var isCallingLLM = false
    @State private var llmResponse: String = ""
    @State private var callError: String? = nil

    private var selectedPaper: Paper? {
        papers.indices.contains(selectedPaperIndex) ? papers[selectedPaperIndex] : nil
    }

    private var resolvedPrompt: String {
        guard let paper = selectedPaper else {
            return userPromptTemplate
        }
        return userPromptTemplate
            .replacingOccurrences(of: "{{title}}", with: paper.title)
            .replacingOccurrences(of: "{{authors}}", with: paper.authors.joined(separator: ", "))
            .replacingOccurrences(of: "{{categories}}", with: paper.categories.joined(separator: ", "))
            .replacingOccurrences(of: "{{abstract}}", with: paper.abstractText)
            .replacingOccurrences(of: "{{full_text}}", with: paper.markdownContent ?? "（全文未转换）")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    // Paper picker
                    if !papers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("选择论文")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Picker("论文", selection: $selectedPaperIndex) {
                                ForEach(papers.indices, id: \.self) { index in
                                    Text(papers[index].title)
                                        .lineLimit(1)
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal)
                    }

                    // System prompt
                    promptBlock(title: "系统提示词", content: systemPrompt, color: AppTheme.secondary)

                    // Resolved user prompt
                    promptBlock(title: "用户提示词（变量已解析）", content: resolvedPrompt, color: AppTheme.primary)

                    // LLM response
                    if !llmResponse.isEmpty {
                        promptBlock(title: "LLM 响应", content: llmResponse, color: .green)
                    }
                    if let error = callError {
                        Text("错误: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Call LLM button
                    Button {
                        callLLM()
                    } label: {
                        HStack {
                            if isCallingLLM { ProgressView().controlSize(.small) }
                            Text(isCallingLLM ? "请求中..." : "发送至 LLM 测试")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
                    }
                    .disabled(isCallingLLM)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("预览测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func promptBlock(title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
            ScrollView {
                Text(content.isEmpty ? "（空）" : content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            .padding(10)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }

    private func callLLM() {
        guard let data = UserDefaults.standard.data(forKey: "llm_config"),
              let config = try? JSONDecoder().decode(LLMProviderConfig.self, from: data) else {
            callError = "未配置 LLM 服务，请先在 LLM 服务商中配置"
            return
        }

        isCallingLLM = true
        llmResponse = ""
        callError = nil

        let service = OpenAICompatibleService(config: config)
        let messages = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: resolvedPrompt)
        ]

        Task {
            do {
                let response = try await service.complete(messages: messages, stream: false)
                await MainActor.run {
                    llmResponse = response
                    isCallingLLM = false
                }
            } catch {
                await MainActor.run {
                    callError = error.localizedDescription
                    isCallingLLM = false
                }
            }
        }
    }
}


#Preview {
    NavigationStack {
        PromptEditorView()
    }
    .modelContainer(for: [PromptTemplate.self, Paper.self], inMemory: true)
}
