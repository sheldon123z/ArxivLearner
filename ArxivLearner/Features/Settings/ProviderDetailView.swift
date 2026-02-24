import SwiftUI
import SwiftData

// MARK: - ProviderDetailView

struct ProviderDetailView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input

    /// The existing provider being edited, or nil when creating a new one.
    let provider: LLMProvider?
    let isNew: Bool

    // MARK: - Form State

    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var providerType: ProviderType = .customOpenAI
    @State private var isEnabled: Bool = true

    // MARK: - Model Management State

    @State private var showAddModel = false
    @State private var modelToEdit: LLMModel? = nil
    @State private var modelToDelete: LLMModel? = nil
    @State private var showDeleteModelConfirm = false

    // MARK: - Connectivity Test State

    @State private var isTesting = false
    @State private var testResult: TestResult? = nil

    // MARK: - Model Discovery State

    @State private var isFetchingModels = false
    @State private var fetchedModels: [PresetModel] = []
    @State private var showModelPicker = false

    // MARK: - Alert State

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showDeleteProviderConfirm = false

    // MARK: - Derived

    private var sortedModels: [LLMModel] {
        (provider?.models ?? []).sorted { ($0.isDefault && !$1.isDefault) || $0.displayName < $1.displayName }
    }

    // MARK: - Body

    var body: some View {
        Form {
            basicInfoSection
            modelsSection
            connectivitySection
            if !isNew {
                deleteSection
            }
        }
        .navigationTitle(isNew ? "添加服务商" : "编辑服务商")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { saveProvider() }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showAddModel) {
            ModelEditSheet(model: nil, provider: provider) { modelId, displayName, contextWindow in
                addModel(modelId: modelId, displayName: displayName, contextWindow: contextWindow)
            }
        }
        .sheet(item: $modelToEdit) { model in
            ModelEditSheet(model: model, provider: provider) { modelId, displayName, contextWindow in
                updateModel(model, modelId: modelId, displayName: displayName, contextWindow: contextWindow)
            }
        }
        .alert("确认删除模型", isPresented: $showDeleteModelConfirm, presenting: modelToDelete) { model in
            Button("删除", role: .destructive) { deleteModel(model) }
            Button("取消", role: .cancel) {}
        } message: { model in
            Text("将删除模型「\(model.displayName)」")
        }
        .alert("确认删除服务商", isPresented: $showDeleteProviderConfirm) {
            Button("删除", role: .destructive) { deleteProvider() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除服务商「\(name)」及其所有模型配置，此操作不可撤销")
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showModelPicker) {
            OpenRouterModelPickerView(
                fetchedModels: fetchedModels,
                existingModelIds: Set(sortedModels.map(\.modelId))
            ) { selected in
                addFetchedModels(selected)
            }
        }
        .onAppear { loadValues() }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section("基本信息") {
            HStack {
                Text("类型")
                Spacer()
                Picker("类型", selection: $providerType) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(AppTheme.primary)
            }

            TextField("服务商名称", text: $name)

            TextField("Base URL", text: $baseURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            SecureField("API Key", text: $apiKey)
                .textContentType(.password)

            Toggle("启用", isOn: $isEnabled)
                .tint(AppTheme.primary)
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        Section {
            if sortedModels.isEmpty {
                Text("暂无模型，点击 + 添加")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(.subheadline)
            } else {
                ForEach(sortedModels) { model in
                    ModelRow(model: model)
                        .contentShape(Rectangle())
                        .onTapGesture { modelToEdit = model }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelToDelete = model
                                showDeleteModelConfirm = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !model.isDefault {
                                Button {
                                    setDefaultModel(model)
                                } label: {
                                    Label("设为默认", systemImage: "star")
                                }
                                .tint(AppTheme.primary)
                            }
                        }
                }
            }

            Button {
                showAddModel = true
            } label: {
                Label("添加模型", systemImage: "plus.circle.fill")
                    .foregroundStyle(AppTheme.primary)
            }

            if providerType == .openRouter {
                Button {
                    fetchOpenRouterModels()
                } label: {
                    HStack(spacing: AppTheme.spacing) {
                        if isFetchingModels {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                        Text(isFetchingModels ? "获取中..." : "从 OpenRouter 获取最新模型")
                    }
                    .foregroundStyle(AppTheme.primary)
                }
                .disabled(isFetchingModels)
            }
        } header: {
            Text("模型")
        } footer: {
            if providerType == .openRouter {
                Text("左滑可删除，右滑可设为默认模型。支持从 OpenRouter API 动态获取最新模型列表")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("左滑可删除，右滑可设为默认模型")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Connectivity Section

    private var connectivitySection: some View {
        Section("连接测试") {
            Button {
                testConnection()
            } label: {
                HStack(spacing: AppTheme.spacing) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "network")
                    }
                    Text(isTesting ? "测试中..." : "测试连接")
                    Spacer()
                    if let result = testResult {
                        testResultBadge(result)
                    }
                }
            }
            .disabled(isTesting || baseURL.isEmpty)
            .foregroundStyle(AppTheme.primary)
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button("删除此服务商", role: .destructive) {
                showDeleteProviderConfirm = true
            }
        }
    }

    // MARK: - Test Result Badge

    @ViewBuilder
    private func testResultBadge(_ result: TestResult) -> some View {
        switch result {
        case .success(let ms):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(ms) ms")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        case .failure(let msg):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Load Values

    private func loadValues() {
        guard let p = provider else { return }
        name = p.name
        baseURL = p.baseURL
        providerType = p.type
        isEnabled = p.isEnabled
        apiKey = (try? KeychainService.shared.retrieve(key: p.apiKeyRef)) ?? ""
    }

    // MARK: - Save Provider

    private func saveProvider() {
        // Persist API key to Keychain
        let keychainKey: String
        if let p = provider {
            keychainKey = p.apiKeyRef
        } else {
            keychainKey = "llm_api_key_\(UUID().uuidString)"
        }
        try? KeychainService.shared.save(key: keychainKey, value: apiKey)

        if let p = provider {
            // Update existing
            p.name = name.trimmingCharacters(in: .whitespaces)
            p.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
            p.type = providerType
            p.isEnabled = isEnabled
        } else {
            // Create new custom provider
            let newProvider = LLMProvider(
                name: name.trimmingCharacters(in: .whitespaces),
                providerType: providerType,
                baseURL: baseURL.trimmingCharacters(in: .whitespaces),
                apiKeyRef: keychainKey,
                isEnabled: isEnabled,
                sortOrder: 999
            )
            modelContext.insert(newProvider)
        }

        try? modelContext.save()

        if isNew {
            dismiss()
        }
    }

    // MARK: - Model Actions

    private func addModel(modelId: String, displayName: String, contextWindow: Int) {
        guard let p = provider else { return }
        let isFirst = p.models.isEmpty
        let model = LLMModel(
            provider: p,
            modelId: modelId,
            displayName: displayName,
            contextWindow: contextWindow,
            isDefault: isFirst,
            isEnabled: true
        )
        modelContext.insert(model)
        p.models.append(model)
        try? modelContext.save()
    }

    private func updateModel(_ model: LLMModel, modelId: String, displayName: String, contextWindow: Int) {
        model.modelId = modelId
        model.displayName = displayName
        model.contextWindow = contextWindow
        try? modelContext.save()
    }

    private func deleteModel(_ model: LLMModel) {
        provider?.models.removeAll { $0.id == model.id }
        modelContext.delete(model)
        try? modelContext.save()
    }

    private func setDefaultModel(_ model: LLMModel) {
        provider?.models.forEach { $0.isDefault = false }
        model.isDefault = true
        try? modelContext.save()
    }

    // MARK: - Delete Provider

    private func deleteProvider() {
        guard let p = provider else { return }
        // Delete Keychain entry
        try? KeychainService.shared.delete(key: p.apiKeyRef)
        modelContext.delete(p)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Test Connection

    private func testConnection() {
        guard !baseURL.isEmpty else { return }

        let testModelId = sortedModels.first(where: { $0.isDefault })?.modelId
            ?? sortedModels.first?.modelId
            ?? "gpt-4o-mini"

        let config = LLMProviderConfig(
            providerId: nil,
            name: name,
            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
            apiKey: apiKey,
            modelId: testModelId
        )

        let service = OpenAICompatibleService(config: config)
        isTesting = true
        testResult = nil

        Task {
            let start = Date()
            do {
                let messages = [LLMMessage(role: "user", content: "Hi")]
                _ = try await service.complete(messages: messages, stream: false)
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                await MainActor.run {
                    isTesting = false
                    testResult = .success(ms: latency)
                }
            } catch let error as LLMError {
                let msg = shortErrorMessage(error)
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(message: msg)
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - OpenRouter Model Discovery

    private func fetchOpenRouterModels() {
        isFetchingModels = true
        Task {
            do {
                let models = try await OpenRouterModelService().fetchModels()
                await MainActor.run {
                    isFetchingModels = false
                    fetchedModels = models
                    showModelPicker = true
                }
            } catch {
                let fallback = OpenRouterModelService.fallbackModels
                await MainActor.run {
                    isFetchingModels = false
                    fetchedModels = fallback
                    showModelPicker = true
                    alertTitle = "获取失败"
                    alertMessage = "无法连接 OpenRouter API，已显示离线备用模型列表"
                    showAlert = true
                }
            }
        }
    }

    private func addFetchedModels(_ models: [PresetModel]) {
        guard let p = provider else { return }
        let existingIds = Set(p.models.map(\.modelId))
        for presetModel in models {
            guard !existingIds.contains(presetModel.id) else { continue }
            let model = LLMModel(
                provider: p,
                modelId: presetModel.id,
                displayName: presetModel.name,
                contextWindow: 128_000,
                isDefault: p.models.isEmpty,
                isEnabled: true
            )
            modelContext.insert(model)
            p.models.append(model)
        }
        try? modelContext.save()
    }

    private func shortErrorMessage(_ error: LLMError) -> String {
        switch error {
        case .invalidURL:           return "URL 无效"
        case .badResponse(let code): return "HTTP \(code)"
        case .invalidResponse:      return "响应异常"
        case .missingAPIKey:        return "API Key 未配置"
        }
    }
}

// MARK: - TestResult

private enum TestResult {
    case success(ms: Int)
    case failure(message: String)
}

// MARK: - ModelRow

private struct ModelRow: View {

    let model: LLMModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    if model.isDefault {
                        Text("默认")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.primary.opacity(0.15))
                            .foregroundStyle(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(model.modelId)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(contextWindowLabel(model.contextWindow))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func contextWindowLabel(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.0fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.0fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

// MARK: - ModelEditSheet

private struct ModelEditSheet: View {

    @Environment(\.dismiss) private var dismiss

    let model: LLMModel?
    let provider: LLMProvider?
    let onSave: (String, String, Int) -> Void

    @State private var modelId: String = ""
    @State private var displayName: String = ""
    @State private var contextWindow: Int = 128_000

    private let contextWindowOptions: [(label: String, value: Int)] = [
        ("4K", 4_096),
        ("8K", 8_192),
        ("16K", 16_384),
        ("32K", 32_768),
        ("64K", 65_536),
        ("128K", 128_000),
        ("200K", 200_000),
        ("1M", 1_000_000),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("模型信息") {
                    TextField("Model ID（如 gpt-4o）", text: $modelId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("显示名称", text: $displayName)

                    HStack {
                        Text("上下文窗口")
                        Spacer()
                        Picker("上下文窗口", selection: $contextWindow) {
                            ForEach(contextWindowOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .navigationTitle(model == nil ? "添加模型" : "编辑模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let finalDisplayName = displayName.isEmpty ? modelId : displayName
                        onSave(modelId.trimmingCharacters(in: .whitespaces),
                               finalDisplayName.trimmingCharacters(in: .whitespaces),
                               contextWindow)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
                    .disabled(modelId.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let m = model {
                    modelId = m.modelId
                    displayName = m.displayName
                    contextWindow = m.contextWindow
                }
            }
        }
    }
}

// MARK: - OpenRouterModelPickerView

private struct OpenRouterModelPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let fetchedModels: [PresetModel]
    let existingModelIds: Set<String>
    let onAdd: ([PresetModel]) -> Void

    @State private var selectedIds: Set<String> = []
    @State private var searchText: String = ""

    private var filteredModels: [PresetModel] {
        let available = fetchedModels.filter { !existingModelIds.contains($0.id) }
        if searchText.isEmpty { return available }
        let query = searchText.lowercased()
        return available.filter {
            $0.id.lowercased().contains(query) || $0.name.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredModels) { model in
                Button {
                    if selectedIds.contains(model.id) {
                        selectedIds.remove(model.id)
                    } else {
                        selectedIds.insert(model.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.name)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(model.id)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if selectedIds.contains(model.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索模型...")
            .navigationTitle("选择模型 (\(filteredModels.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加 (\(selectedIds.count))") {
                        let selected = fetchedModels.filter { selectedIds.contains($0.id) }
                        onAdd(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProviderDetailView(provider: nil, isNew: true)
    }
    .modelContainer(for: [LLMProvider.self, LLMModel.self], inMemory: true)
}
