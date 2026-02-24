import SwiftUI
import SwiftData

// MARK: - SavedSearchListView

struct SavedSearchListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]

    var onSelect: ((SavedSearch) -> Void)?

    var body: some View {
        Group {
            if savedSearches.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(savedSearches) { saved in
                        SavedSearchRow(savedSearch: saved)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect?(saved)
                            }
                    }
                    .onDelete(perform: deleteSavedSearch)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("已保存的搜索")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Private

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            Text("暂无保存的搜索")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text("在搜索结果页点击书签图标保存搜索")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func deleteSavedSearch(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedSearches[index])
        }
        try? modelContext.save()
    }
}

// MARK: - SavedSearchRow

struct SavedSearchRow: View {

    let savedSearch: SavedSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(savedSearch.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if savedSearch.isEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                } else {
                    Image(systemName: "bell.slash")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Text(savedSearch.query)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let category = savedSearch.filterCategory {
                    TagChip(text: category, color: AppTheme.categoryColor(for: category))
                }

                Spacer()

                if let lastChecked = savedSearch.lastCheckedAt {
                    Text("上次检查：\(lastChecked, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                } else {
                    Text("从未检查")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SaveSearchSheet

struct SaveSearchSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let query: String
    let category: String?
    var onSaved: (() -> Void)?

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("搜索信息") {
                    LabeledContent("关键词", value: query)
                    if let category {
                        LabeledContent("分类", value: category)
                    }
                }

                Section("订阅名称") {
                    TextField("为这个搜索起个名字", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("保存搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSearch()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = query
            }
        }
    }

    private func saveSearch() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let saved = SavedSearch(
            name: trimmedName,
            query: query,
            filterCategory: category
        )
        modelContext.insert(saved)
        try? modelContext.save()

        // 请求通知权限（首次保存订阅时）
        NotificationManager.shared.requestPermission()

        onSaved?()
        dismiss()
    }
}
