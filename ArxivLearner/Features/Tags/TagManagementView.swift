import SwiftUI
import SwiftData

// MARK: - TagManagementView

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.createdAt, order: .reverse) private var allTags: [Tag]

    @State private var showAddSheet = false
    @State private var editingTag: Tag?
    @State private var newTagName = ""
    @State private var newTagColorHex = AppTheme.tagPresetColors.first ?? "6C5CE7"

    var body: some View {
        NavigationStack {
            List {
                ForEach(allTags, id: \.name) { tag in
                    TagRowView(tag: tag) {
                        editingTag = tag
                    }
                }
                .onDelete(perform: deleteTags)
            }
            .navigationTitle("标签管理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                TagEditSheet(
                    title: "新建标签",
                    name: $newTagName,
                    colorHex: $newTagColorHex
                ) {
                    createTag()
                    showAddSheet = false
                } onCancel: {
                    newTagName = ""
                    newTagColorHex = AppTheme.tagPresetColors.first ?? "6C5CE7"
                    showAddSheet = false
                }
            }
            .sheet(item: $editingTag) { tag in
                TagEditSheetForExisting(tag: tag)
            }
            .overlay {
                if allTags.isEmpty {
                    ContentUnavailableView(
                        "暂无标签",
                        systemImage: "tag",
                        description: Text("点击右上角 + 创建新标签")
                    )
                }
            }
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorHex: newTagColorHex)
        modelContext.insert(tag)
        newTagName = ""
        newTagColorHex = AppTheme.tagPresetColors.first ?? "6C5CE7"
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(allTags[index])
        }
    }
}

// MARK: - TagRowView

private struct TagRowView: View {
    let tag: Tag
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacing) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 14, height: 14)

            Text(tag.name)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text("\(tag.papers.count) 篇")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - TagEditSheet (for new tag creation)

struct TagEditSheet: View {
    let title: String
    @Binding var name: String
    @Binding var colorHex: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("标签名称") {
                    TextField("输入标签名", text: $name)
                }

                Section("选择颜色") {
                    colorPickerGrid
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定") {
                        onConfirm()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var colorPickerGrid: some View {
        let uniqueColors = Array(Set(AppTheme.tagPresetColors))
        let columns = Array(repeating: GridItem(.flexible()), count: 5)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(uniqueColors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if hex == colorHex {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture {
                        colorHex = hex
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TagEditSheetForExisting (editing an existing Tag)

private struct TagEditSheetForExisting: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag

    @State private var name: String
    @State private var colorHex: String

    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
        _colorHex = State(initialValue: tag.colorHex)
    }

    var body: some View {
        TagEditSheet(
            title: "编辑标签",
            name: $name,
            colorHex: $colorHex
        ) {
            tag.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            tag.colorHex = colorHex
            dismiss()
        } onCancel: {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    TagManagementView()
        .modelContainer(for: [Tag.self, Paper.self], inMemory: true)
}
