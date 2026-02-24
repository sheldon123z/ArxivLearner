import SwiftUI
import SwiftData

// MARK: - ProviderSettingsView

struct ProviderSettingsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Query

    @Query(sort: \LLMProvider.sortOrder, order: .forward)
    private var providers: [LLMProvider]

    // MARK: - State

    @State private var showAddSheet = false
    @State private var showPresetPicker = false
    @State private var showCustomForm = false
    @State private var providerToDelete: LLMProvider?
    @State private var showDeleteConfirm = false

    // MARK: - Body

    var body: some View {
        List {
            if providers.isEmpty {
                emptyState
            } else {
                providersSection
            }
        }
        .navigationTitle("LLM 服务商")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .confirmationDialog("添加服务商", isPresented: $showAddSheet, titleVisibility: .visible) {
            Button("从预设选择") {
                showPresetPicker = true
            }
            Button("自定义 (OpenAI 兼容)") {
                showCustomForm = true
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetProviderPickerView { preset in
                addPresetProvider(preset)
            }
        }
        .sheet(isPresented: $showCustomForm) {
            NavigationStack {
                ProviderDetailView(provider: nil, isNew: true)
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm, presenting: providerToDelete) { provider in
            Button("删除", role: .destructive) {
                deleteProvider(provider)
            }
            Button("取消", role: .cancel) {}
        } message: { provider in
            Text("将删除服务商「\(provider.name)」及其所有模型配置")
        }
    }

    // MARK: - Providers Section

    @ViewBuilder
    private var providersSection: some View {
        Section {
            ForEach(providers) { provider in
                NavigationLink {
                    ProviderDetailView(provider: provider, isNew: false)
                } label: {
                    ProviderRow(provider: provider)
                }
            }
            .onDelete { indexSet in
                guard let index = indexSet.first else { return }
                providerToDelete = providers[index]
                showDeleteConfirm = true
            }
            .onMove { from, to in
                reorderProviders(from: from, to: to)
            }
        } header: {
            HStack {
                Text("已配置服务商")
                Spacer()
                EditButton()
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: AppTheme.spacing) {
                Image(systemName: "cloud.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("尚未配置 LLM 服务商")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("点击右上角 + 添加服务商")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Actions

    private func addPresetProvider(_ preset: PresetProvider) {
        let sortOrder = providers.count
        let provider = LLMProvider(
            name: preset.name,
            providerType: providerType(for: preset.id),
            baseURL: preset.baseURL,
            apiKeyRef: "llm_api_key_\(preset.id)",
            isEnabled: true,
            sortOrder: sortOrder
        )

        modelContext.insert(provider)

        // Seed preset models
        for (index, presetModel) in preset.models.enumerated() {
            let model = LLMModel(
                provider: provider,
                modelId: presetModel.id,
                displayName: presetModel.name,
                contextWindow: 128_000,
                isDefault: index == 0,
                isEnabled: true
            )
            modelContext.insert(model)
            provider.models.append(model)
        }

        try? modelContext.save()
    }

    private func providerType(for presetId: String) -> ProviderType {
        switch presetId {
        case "openai":      return .openai
        case "anthropic":   return .anthropic
        case "google":      return .google
        case "deepseek":    return .deepseek
        case "zhipu":       return .zhipu
        case "dashscope":   return .dashscope
        case "minimax":     return .minimax
        case "openrouter":  return .openRouter
        default:            return .customOpenAI
        }
    }

    private func deleteProvider(_ provider: LLMProvider) {
        modelContext.delete(provider)
        try? modelContext.save()
    }

    private func reorderProviders(from source: IndexSet, to destination: Int) {
        var reordered = providers
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, provider) in reordered.enumerated() {
            provider.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - ProviderRow

private struct ProviderRow: View {

    let provider: LLMProvider

    var body: some View {
        HStack(spacing: AppTheme.spacing) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(provider.models.count) 个模型")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // Enabled badge
            Text(provider.isEnabled ? "启用" : "禁用")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(provider.isEnabled ? AppTheme.primary.opacity(0.15) : Color.gray.opacity(0.15))
                .foregroundStyle(provider.isEnabled ? AppTheme.primary : AppTheme.textSecondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    private var typeIcon: String {
        switch provider.type {
        case .openai:       return "sparkles"
        case .anthropic:    return "a.circle.fill"
        case .google:       return "g.circle.fill"
        case .deepseek:     return "d.circle.fill"
        case .openRouter:   return "arrow.triangle.branch"
        case .customOpenAI: return "wrench.and.screwdriver"
        case .zhipu:        return "z.circle.fill"
        case .dashscope:    return "cloud.fill"
        case .minimax:      return "m.circle.fill"
        }
    }

    private var iconBackground: Color {
        switch provider.type {
        case .openai:       return Color(hex: "10A37F")
        case .anthropic:    return Color(hex: "D4A574")
        case .google:       return Color(hex: "4285F4")
        case .deepseek:     return Color(hex: "4A90D9")
        case .openRouter:   return Color(hex: "6C5CE7")
        case .customOpenAI: return Color.gray
        case .zhipu:        return Color(hex: "2563EB")
        case .dashscope:    return Color(hex: "FF6A00")
        case .minimax:      return Color(hex: "7C3AED")
        }
    }
}

// MARK: - PresetProviderPickerView

private struct PresetProviderPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var existingProviders: [LLMProvider]

    let onSelect: (PresetProvider) -> Void

    var body: some View {
        NavigationStack {
            List(LLMProviderRegistry.allProviders) { preset in
                let alreadyAdded = existingProviders.contains { $0.name == preset.name }
                Button {
                    if !alreadyAdded {
                        onSelect(preset)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .foregroundStyle(alreadyAdded ? AppTheme.textSecondary : AppTheme.textPrimary)
                            Text("\(preset.models.count) 个预设模型")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if alreadyAdded {
                            Text("已添加")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .disabled(alreadyAdded)
            }
            .navigationTitle("选择预设服务商")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
    .modelContainer(for: [LLMProvider.self, LLMModel.self], inMemory: true)
}
