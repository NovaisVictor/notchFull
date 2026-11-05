import CoreGraphics

/// Sizes of the open notch, derived from the widgets' widths in cells.
enum WidgetGridMetrics {
    /// One grid cell; a widget `span` cells wide is `span × cellWidth` points.
    static let cellWidth: CGFloat = 58
    static let cardHeight: CGFloat = 132
    static let spacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 18
    static let topGap: CGFloat = 8
    static let bottomPadding: CGFloat = 14
    static let minOpenWidth: CGFloat = 360
    /// Wider layouts scroll horizontally instead of growing past this.
    static let maxOpenWidth: CGFloat = 960

    static func cardWidth(span: Int) -> CGFloat {
        CGFloat(span) * cellWidth
    }

    static func openSize(for spans: [Int], closedHeight: CGFloat) -> CGSize {
        let cards = spans.map(cardWidth(span:)).reduce(0, +)
        let gaps = CGFloat(max(spans.count - 1, 0)) * spacing
        let width = min(max(cards + gaps + horizontalPadding * 2, minOpenWidth), maxOpenWidth)
        return CGSize(width: width, height: openHeight(closedHeight: closedHeight))
    }

    static func maxOpenSize(closedHeight: CGFloat) -> CGSize {
        CGSize(width: maxOpenWidth, height: openHeight(closedHeight: closedHeight))
    }

    private static func openHeight(closedHeight: CGFloat) -> CGFloat {
        closedHeight + topGap + cardHeight + bottomPadding
    }
}
