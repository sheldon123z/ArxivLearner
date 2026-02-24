import SwiftUI
import SwiftData

// MARK: - AnnotationListView

struct AnnotationListView: View {
    let annotations: [Annotation]
    var onJumpToPage: (Int) -> Void
    var onDelete: (Annotation) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if annotations.isEmpty {
                    ContentUnavailableView(
                        "暂无注释",
                        systemImage: "pencil.and.list.clipboard",
                        description: Text("选中文字后高亮，或长按添加注释")
                    )
                } else {
                    List {
                        ForEach(sortedAnnotations, id: \.persistentModelID) { annotation in
                            AnnotationRow(annotation: annotation)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onJumpToPage(annotation.pageIndex)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDelete(annotation)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("注释列表")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sortedAnnotations: [Annotation] {
        annotations.sorted {
            if $0.pageIndex != $1.pageIndex {
                return $0.pageIndex < $1.pageIndex
            }
            return $0.rectY < $1.rectY
        }
    }
}

// MARK: - AnnotationRow

private struct AnnotationRow: View {
    let annotation: Annotation

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: annotation.annotationType == .highlight ? "highlighter" : "note.text")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: annotation.colorHex))
                .frame(width: 28, height: 28)
                .background(Color(hex: annotation.colorHex).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("第 \(annotation.pageIndex + 1) 页")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Circle()
                        .fill(Color(hex: annotation.colorHex))
                        .frame(width: 10, height: 10)
                }

                if annotation.text.isEmpty {
                    Text("（空注释）")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .italic()
                } else {
                    Text(annotation.text)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
