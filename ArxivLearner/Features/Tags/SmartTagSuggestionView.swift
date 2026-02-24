import SwiftUI
import SwiftData

// MARK: - SmartTagSuggestionView

/// Shows LLM-generated tag suggestions for a paper.
struct SmartTagSuggestionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var providers: [LLMProvider]

    let paper: Paper
    @Binding var selectedTagNames: Set<String>

    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在分析论文，生成标签建议...")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task { await fetchSuggestions() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if suggestions.isEmpty {
                    ContentUnavailableView("暂无建议", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI 建议以下标签，点击即可添加：")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)

                        FlowLayout(spacing: 10) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                SuggestionChip(
                                    text: suggestion,
                                    isSelected: selectedTagNames.contains(suggestion)
                                ) {
                                    toggleSuggestion(suggestion)
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("智能标签建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                await fetchSuggestions()
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func toggleSuggestion(_ name: String) {
        if selectedTagNames.contains(name) {
            selectedTagNames.remove(name)
        } else {
            // Create Tag if it doesn't exist yet
            createTagIfNeeded(name: name)
            selectedTagNames.insert(name)
        }
    }

    private func createTagIfNeeded(name: String) {
        let colorHex = AppTheme.tagPresetColors.randomElement() ?? "6C5CE7"
        let tag = Tag(name: name, colorHex: colorHex)
        modelContext.insert(tag)
    }

    // MARK: - LLM Call

    private func fetchSuggestions() async {
        guard let provider = providers.first(where: { $0.isEnabled }),
              let model = provider.models.first(where: { $0.isEnabled }) else {
            errorMessage = "未配置 LLM 服务商，请先在设置中配置"
            return
        }

        isLoading = true
        errorMessage = nil

        let existingTagsText = paper.tagItems.map { $0.name }.joined(separator: "、")
        let prompt = """
        请根据以下论文信息，从学术角度推荐 3~5 个简洁的中文或英文标签（每个不超过 10 字）。
        标签应反映研究方向、方法或主题。请以 JSON 数组格式返回，例如：["深度学习","目标检测","Transformer"]

        论文标题：\(paper.title)
        论文摘要：\(paper.abstractText.prefix(500))
        已有标签：\(existingTagsText.isEmpty ? "无" : existingTagsText)

        请只返回 JSON 数组，不要包含其他内容。
        """

        let messages = [LLMMessage(role: "user", content: prompt)]

        do {
            let response = try await LLMRouter.shared.complete(
                messages: messages,
                provider: provider,
                model: model,
                stream: false
            )
            let parsed = parseTagsFromJSON(response)
            await MainActor.run {
                suggestions = parsed
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "请求失败：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func parseTagsFromJSON(_ raw: String) -> [String] {
        // Extract JSON array from the response
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startIdx = trimmed.firstIndex(of: "["),
              let endIdx = trimmed.lastIndex(of: "]") else {
            return []
        }
        let jsonString = String(trimmed[startIdx...endIdx])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

// MARK: - SuggestionChip

private struct SuggestionChip: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.primary : AppTheme.cardBackground)
            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? AppTheme.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Preview

#Preview {
    SmartTagSuggestionView(
        paper: Paper(arxivId: "test", title: "Attention Is All You Need", abstractText: "We propose a new network architecture, the Transformer."),
        selectedTagNames: .constant([])
    )
    .modelContainer(for: [Tag.self, Paper.self, LLMProvider.self, LLMModel.self], inMemory: true)
}
