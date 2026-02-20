import SwiftUI
import SwiftData

struct CompactCardView: View {
    let paper: ArxivPaperDTO
    let modelContext: ModelContext
    @State private var isFavorite = false
    @State private var showFullCard = false

    var body: some View {
        Button { showFullCard = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Top row: categories + favorite
                HStack {
                    ForEach(paper.categories.prefix(2), id: \.self) { cat in
                        TagChip(
                            text: cat,
                            color: AppTheme.categoryColor(for: cat)
                        )
                    }
                    Spacer()
                    Button {
                        isFavorite.toggle()
                        saveFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : AppTheme.textSecondary)
                    }
                }

                // Title
                Text(paper.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)

                // Author + date
                HStack {
                    Text(authorSummary)
                    Text("·")
                    Text(paper.publishedDate, format: .dateTime.year().month())
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                // Abstract
                Text(paper.abstractText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(
                color: .black.opacity(0.1),
                radius: AppTheme.cardShadowRadius,
                x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showFullCard) {
            FullCardView(paper: paper, modelContext: modelContext)
        }
    }

    private var authorSummary: String {
        if paper.authors.count <= 2 {
            return paper.authors.joined(separator: ", ")
        }
        return "\(paper.authors[0]) et al."
    }

    private func saveFavorite() {
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite = isFavorite
        } else if isFavorite {
            let newPaper = Paper(
                arxivId: paper.arxivId,
                title: paper.title,
                authors: paper.authors,
                abstractText: paper.abstractText,
                categories: paper.categories,
                publishedDate: paper.publishedDate,
                pdfURL: paper.pdfURL.absoluteString,
                isFavorite: true
            )
            modelContext.insert(newPaper)
        }
        try? modelContext.save()
    }
}
