import SwiftUI

// MARK: - OutlineView

struct OutlineView: View {
    let items: [OutlineItem]
    var onJumpToPage: (Int) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "无目录",
                        systemImage: "list.bullet.rectangle",
                        description: Text("该 PDF 不包含书签目录")
                    )
                } else {
                    List(items, children: \.optionalChildren) { item in
                        OutlineItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onJumpToPage(item.pageIndex)
                            }
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: CGFloat(item.indentLevel) * 12 + 16,
                                bottom: 0,
                                trailing: 16
                            ))
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - OutlineItemRow

private struct OutlineItemRow: View {
    let item: OutlineItem

    var body: some View {
        HStack {
            Image(systemName: item.children.isEmpty ? "doc.text" : "folder")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 16)

            Text(item.title)
                .font(item.indentLevel == 0 ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            Text("P\(item.pageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - OutlineItem List Extension

extension OutlineItem {
    /// Returns nil when children is empty so List doesn't show disclosure indicator
    var optionalChildren: [OutlineItem]? {
        children.isEmpty ? nil : children
    }
}
