import SwiftUI
import SwiftData

// MARK: - TagSelectionSheet

/// A sheet for selecting/deselecting tags on a paper, with optional multi-paper batch mode.
struct TagSelectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.createdAt, order: .reverse) private var allTags: [Tag]

    /// Papers whose tags are being edited (batch mode when count > 1).
    let papers: [Paper]

    @State private var selectedTagNames: Set<String> = []
    @State private var showNewTagSheet = false
    @State private var newTagName = ""
    @State private var newTagColorHex = AppTheme.tagPresetColors.first ?? "6C5CE7"
    @State private var showSmartSuggestion = false

    init(papers: [Paper]) {
        self.papers = papers
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(allTags, id: \.name) { tag in
                    tagRow(tag)
                }

                Section {
                    Button {
                        showNewTagSheet = true
                    } label: {
                        Label("新建标签", systemImage: "plus.circle")
                            .foregroundStyle(AppTheme.primary)
                    }

                    if papers.count == 1, let paper = papers.first {
                        Button {
                            showSmartSuggestion = true
                        } label: {
                            Label("智能建议", systemImage: "sparkles")
                                .foregroundStyle(AppTheme.secondary)
                        }
                        .sheet(isPresented: $showSmartSuggestion) {
                            SmartTagSuggestionView(paper: paper, selectedTagNames: $selectedTagNames)
                        }
                    }
                }
            }
            .navigationTitle(papers.count == 1 ? "选择标签" : "批量选择标签（\(papers.count) 篇）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        applyTags()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showNewTagSheet) {
                TagEditSheet(
                    title: "新建标签",
                    name: $newTagName,
                    colorHex: $newTagColorHex
                ) {
                    createAndSelectTag()
                    showNewTagSheet = false
                } onCancel: {
                    resetNewTagFields()
                    showNewTagSheet = false
                }
            }
            .onAppear {
                loadInitialSelection()
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tag Row

    private func tagRow(_ tag: Tag) -> some View {
        let isSelected = selectedTagNames.contains(tag.name)
        return HStack(spacing: AppTheme.spacing) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 12, height: 12)

            Text(tag.name)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedTagNames.remove(tag.name)
            } else {
                selectedTagNames.insert(tag.name)
            }
        }
    }

    // MARK: - Helpers

    private func loadInitialSelection() {
        // For single paper: load its current tags
        // For batch: start with empty selection (user chooses what to add)
        if papers.count == 1, let paper = papers.first {
            selectedTagNames = Set(paper.tagItems.map { $0.name })
        }
    }

    private func applyTags() {
        for paper in papers {
            // Resolve Tag objects for the selected names
            let selectedTags = allTags.filter { selectedTagNames.contains($0.name) }

            if papers.count == 1 {
                // Single paper: replace tag list entirely
                paper.tagItems = selectedTags
            } else {
                // Batch: add selected tags (union, don't remove existing)
                let existingNames = Set(paper.tagItems.map { $0.name })
                let toAdd = selectedTags.filter { !existingNames.contains($0.name) }
                paper.tagItems.append(contentsOf: toAdd)
            }
        }
    }

    private func createAndSelectTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorHex: newTagColorHex)
        modelContext.insert(tag)
        selectedTagNames.insert(trimmed)
        resetNewTagFields()
    }

    private func resetNewTagFields() {
        newTagName = ""
        newTagColorHex = AppTheme.tagPresetColors.first ?? "6C5CE7"
    }
}

// MARK: - TagRemovalSheet

/// A sheet for removing tags from a batch of papers.
struct TagRemovalSheet: View {
    @Environment(\.dismiss) private var dismiss

    let papers: [Paper]

    @Query(sort: \Tag.createdAt, order: .reverse) private var allTags: [Tag]
    @State private var selectedTagNames: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(commonTags, id: \.name) { tag in
                    tagRow(tag)
                }
            }
            .navigationTitle("移除标签（\(papers.count) 篇）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("移除") {
                        removeTags()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
                    .disabled(selectedTagNames.isEmpty)
                }
            }
            .overlay {
                if commonTags.isEmpty {
                    ContentUnavailableView("无共同标签", systemImage: "tag.slash")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // Tags that appear on at least one of the selected papers
    private var commonTags: [Tag] {
        let allPaperTagNames = papers.flatMap { $0.tagItems.map { $0.name } }
        let uniqueNames = Set(allPaperTagNames)
        return allTags.filter { uniqueNames.contains($0.name) }
    }

    private func tagRow(_ tag: Tag) -> some View {
        let isSelected = selectedTagNames.contains(tag.name)
        return HStack(spacing: AppTheme.spacing) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 12, height: 12)
            Text(tag.name)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedTagNames.remove(tag.name)
            } else {
                selectedTagNames.insert(tag.name)
            }
        }
    }

    private func removeTags() {
        for paper in papers {
            paper.tagItems.removeAll { selectedTagNames.contains($0.name) }
        }
    }
}

// MARK: - Preview

#Preview {
    TagSelectionSheet(papers: [])
        .modelContainer(for: [Tag.self, Paper.self], inMemory: true)
}
