import SwiftUI
import SwiftData

// MARK: - SwipeAction

enum SwipeAction {
    case favorite   // 右滑收藏
    case skip       // 左滑跳过
    case expand     // 上滑展开
    case none
}

// MARK: - SwipeCardView

struct SwipeCardView: View {

    let papers: [ArxivPaperDTO]
    let modelContext: ModelContext
    var onExhausted: (() -> Void)?

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var showFullCard: Bool = false
    @State private var expandPaper: ArxivPaperDTO? = nil
    @State private var lastSwipeAction: SwipeAction = .none

    // MARK: Thresholds

    private let horizontalThreshold: CGFloat = 100
    private let verticalThreshold: CGFloat = 150

    // MARK: Body

    var body: some View {
        ZStack {
            if currentIndex < papers.count {
                // 下方预览卡（下一张）
                if currentIndex + 1 < papers.count {
                    cardView(paper: papers[currentIndex + 1], isBackground: true)
                        .scaleEffect(0.94)
                        .offset(y: 16)
                        .zIndex(0)
                }
                // 当前卡片
                cardView(paper: papers[currentIndex], isBackground: false)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 20))
                    .gesture(dragGesture)
                    .zIndex(1)
                    .overlay(swipeIndicatorOverlay)
            } else {
                exhaustedView
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging ? false : true)
        .fullScreenCover(item: $expandPaper) { paper in
            FullCardView(paper: paper, modelContext: modelContext)
        }
    }

    // MARK: - Card View

    private func cardView(paper: ArxivPaperDTO, isBackground: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分类标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(paper.categories.prefix(4), id: \.self) { cat in
                        TagChip(
                            text: cat,
                            color: AppTheme.categoryColor(for: cat)
                        )
                    }
                }
            }

            // 标题
            Text(paper.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // 作者
            if !paper.authors.isEmpty {
                Text(paper.authors.prefix(3).joined(separator: ", ") + (paper.authors.count > 3 ? " 等" : ""))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Divider()

            // 摘要
            Text(paper.abstractText)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                .lineLimit(8)

            Spacer()

            // 底部日期和提示
            HStack {
                Text(paper.publishedDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if !isBackground {
                    swipeHints
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        .shadow(
            color: .black.opacity(0.12),
            radius: AppTheme.cardShadowRadius,
            x: 0, y: 4
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Swipe Hints

    private var swipeHints: some View {
        HStack(spacing: 12) {
            Label("收藏", systemImage: "heart")
                .font(.caption2)
                .foregroundStyle(.green.opacity(0.7))
            Label("跳过", systemImage: "xmark")
                .font(.caption2)
                .foregroundStyle(.red.opacity(0.7))
            Label("详情", systemImage: "arrow.up")
                .font(.caption2)
                .foregroundStyle(AppTheme.primary.opacity(0.7))
        }
    }

    // MARK: - Swipe Indicator Overlay

    @ViewBuilder
    private var swipeIndicatorOverlay: some View {
        if isDragging {
            let action = currentSwipeAction
            ZStack {
                if action == .favorite {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(.green, lineWidth: 3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    VStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .shadow(radius: 4)
                        Text("收藏")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    .opacity(min(1.0, abs(dragOffset.width) / horizontalThreshold))
                } else if action == .skip {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(.red, lineWidth: 3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                            .shadow(radius: 4)
                        Text("跳过")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    .opacity(min(1.0, abs(dragOffset.width) / horizontalThreshold))
                } else if action == .expand {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(AppTheme.primary, lineWidth: 3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    VStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.primary)
                            .shadow(radius: 4)
                        Text("查看详情")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primary)
                    }
                    .opacity(min(1.0, abs(dragOffset.height) / verticalThreshold))
                }
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                handleSwipeEnd(translation: value.translation)
            }
    }

    // MARK: - Swipe Logic

    private var currentSwipeAction: SwipeAction {
        let absH = abs(dragOffset.width)
        let absV = abs(dragOffset.height)

        // 上滑优先（垂直拖动且超过阈值一半）
        if dragOffset.height < -50 && absV > absH {
            return .expand
        }
        if dragOffset.width > horizontalThreshold / 2 {
            return .favorite
        }
        if dragOffset.width < -horizontalThreshold / 2 {
            return .skip
        }
        return .none
    }

    private func handleSwipeEnd(translation: CGSize) {
        let absH = abs(translation.width)
        let absV = abs(translation.height)

        // 上滑展开详情
        if translation.height < -verticalThreshold && absV > absH {
            triggerExpand()
            resetCard()
            return
        }

        // 右滑收藏
        if translation.width > horizontalThreshold {
            triggerFavorite()
            advanceCard(toRight: true)
            return
        }

        // 左滑跳过
        if translation.width < -horizontalThreshold {
            triggerSkip()
            advanceCard(toRight: false)
            return
        }

        // 未达阈值，回弹
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }

    private func advanceCard(toRight: Bool) {
        let exitX: CGFloat = toRight ? 600 : -600
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: exitX, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            dragOffset = .zero
            if currentIndex >= papers.count {
                onExhausted?()
            }
        }
    }

    private func resetCard() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }

    // MARK: - Actions

    private func triggerFavorite() {
        guard currentIndex < papers.count else { return }
        let paper = papers[currentIndex]
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite = true
        } else {
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

    private func triggerSkip() {
        guard currentIndex < papers.count else { return }
        let paper = papers[currentIndex]
        let arxivId = paper.arxivId
        let descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate { $0.arxivId == arxivId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.viewedAt = .now
        } else {
            let newPaper = Paper(
                arxivId: paper.arxivId,
                title: paper.title,
                authors: paper.authors,
                abstractText: paper.abstractText,
                categories: paper.categories,
                publishedDate: paper.publishedDate,
                pdfURL: paper.pdfURL.absoluteString,
                viewedAt: .now
            )
            modelContext.insert(newPaper)
        }
        try? modelContext.save()
    }

    private func triggerExpand() {
        guard currentIndex < papers.count else { return }
        expandPaper = papers[currentIndex]
    }

    // MARK: - Exhausted View

    private var exhaustedView: some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primary.opacity(0.6))

            Text("已浏览全部结果")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("向上滚动加载更多，或重新搜索")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - ArxivPaperDTO Identifiable

extension ArxivPaperDTO: Identifiable {
    public var id: String { arxivId }
}
