import SwiftUI
import SwiftData

// MARK: - ModelAssignmentView

/// Shows a scene-to-model assignment table.
/// Assignments are stored in UserDefaults as [sceneRawValue: modelUUID].
struct ModelAssignmentView: View {

    // MARK: - Query

    @Query(sort: \LLMProvider.sortOrder, order: .forward)
    private var providers: [LLMProvider]

    // MARK: - Scenes (exclude globalSystem and custom)

    private let assignableScenes: [PromptScene] = PromptScene.allCases.filter {
        $0 != .globalSystem && $0 != .custom
    }

    // MARK: - State

    /// In-memory copy of [sceneRawValue: modelUUID string].
    @State private var assignments: [String: String] = [:]

    // MARK: - Computed

    private var allEnabledModels: [LLMModel] {
        providers
            .filter { $0.isEnabled }
            .flatMap { $0.models }
            .filter { $0.isEnabled }
    }

    // MARK: - Body

    var body: some View {
        List {
            if allEnabledModels.isEmpty {
                emptyModelsState
            } else {
                assignmentSection
            }
        }
        .navigationTitle("模型分配")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadAssignments() }
    }

    // MARK: - Assignment Section

    private var assignmentSection: some View {
        Section {
            ForEach(assignableScenes, id: \.self) { scene in
                SceneAssignmentRow(
                    scene: scene,
                    models: allEnabledModels,
                    selectedModelId: binding(for: scene)
                )
            }
        } header: {
            Text("场景 → 模型")
        } footer: {
            Text("选择每个分析场景默认使用的模型。选择「自动」时将使用全局默认模型。")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Empty Models State

    private var emptyModelsState: some View {
        Section {
            VStack(spacing: AppTheme.spacing) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("无可用模型")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("请先在「LLM 服务商」中添加并启用服务商和模型")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Binding

    private func binding(for scene: PromptScene) -> Binding<String> {
        Binding(
            get: { assignments[scene.rawValue] ?? "" },
            set: { newValue in
                assignments[scene.rawValue] = newValue
                saveAssignments()
            }
        )
    }

    // MARK: - Persistence

    private func loadAssignments() {
        if let saved = UserDefaults.standard.dictionary(forKey: "model_assignments") as? [String: String] {
            assignments = saved
        }
    }

    private func saveAssignments() {
        UserDefaults.standard.set(assignments, forKey: "model_assignments")
    }
}

// MARK: - SceneAssignmentRow

private struct SceneAssignmentRow: View {

    let scene: PromptScene
    let models: [LLMModel]
    @Binding var selectedModelId: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(scene.displayName)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                if let model = selectedModel {
                    Text("\(model.provider?.name ?? "未知") · \(model.modelId)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("自动（全局默认）")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            Menu {
                // Auto option
                Button {
                    selectedModelId = ""
                } label: {
                    if selectedModelId.isEmpty {
                        Label("自动（全局默认）", systemImage: "checkmark")
                    } else {
                        Text("自动（全局默认）")
                    }
                }

                Divider()

                // Models grouped by provider
                ForEach(groupedModels, id: \.providerName) { group in
                    Section(group.providerName) {
                        ForEach(group.models) { model in
                            Button {
                                selectedModelId = model.id.uuidString
                            } label: {
                                if selectedModelId == model.id.uuidString {
                                    Label(model.displayName, systemImage: "checkmark")
                                } else {
                                    Text(model.displayName)
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
            }
        }
    }

    private var selectedModel: LLMModel? {
        guard !selectedModelId.isEmpty,
              let uuid = UUID(uuidString: selectedModelId) else { return nil }
        return models.first { $0.id == uuid }
    }

    private var groupedModels: [(providerName: String, models: [LLMModel])] {
        var dict: [String: [LLMModel]] = [:]
        for model in models {
            let key = model.provider?.name ?? "未知"
            dict[key, default: []].append(model)
        }
        return dict.map { (providerName: $0.key, models: $0.value) }
            .sorted { $0.providerName < $1.providerName }
    }
}

#Preview {
    NavigationStack {
        ModelAssignmentView()
    }
    .modelContainer(for: [LLMProvider.self, LLMModel.self], inMemory: true)
}
