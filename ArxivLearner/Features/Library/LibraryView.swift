import SwiftUI
import SwiftData

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @Query private var allPapers: [Paper]
    @Environment(\.modelContext) private var modelContext

    var filteredPapers: [Paper] {
        switch viewModel.selectedFilter {
        case .favorites:
            return allPapers.filter { $0.isFavorite }
        case .downloaded:
            return allPapers.filter { $0.isDownloaded }
        case .all:
            return allPapers
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                Picker("筛选", selection: $viewModel.selectedFilter) {
                    ForEach(LibraryViewModel.Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Paper list
                if filteredPapers.isEmpty {
                    ContentUnavailableView(
                        "暂无论文",
                        systemImage: "book.closed",
                        description: Text("搜索并收藏论文后会在这里显示")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.spacing) {
                            ForEach(filteredPapers, id: \.arxivId) { paper in
                                LibraryCardView(paper: paper)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("文库")
        }
    }
}

struct LibraryCardView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ForEach(paper.categories.prefix(2), id: \.self) { cat in
                    TagChip(text: cat, color: AppTheme.categoryColor(for: cat))
                }

                Spacer()

                if paper.convertStatus == .completed {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                }

                if paper.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Image(systemName: paper.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(paper.isFavorite ? .red : AppTheme.textSecondary)
            }

            Text(paper.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            HStack {
                Text(paper.authors.first ?? "")
                if paper.authors.count > 1 { Text("et al.") }
                Text("·")
                Text(paper.publishedDate, format: .dateTime.year().month())
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            Text(paper.abstractText)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(color: .black.opacity(0.1), radius: AppTheme.cardShadowRadius, x: 0, y: 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Paper.self, inMemory: true)
}
