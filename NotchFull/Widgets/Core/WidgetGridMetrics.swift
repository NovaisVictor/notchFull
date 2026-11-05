import CoreGraphics

/// Sizes of the open notch, derived from the widgets' widths in cells and the island size settings.
struct WidgetGridMetrics {
    static let spacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 18
    static let topGap: CGFloat = 8
    static let bottomPadding: CGFloat = 14
    static let minOpenWidth: CGFloat = 360
    /// Wider layouts scroll horizontally instead of growing past this.
    static let maxOpenWidth: CGFloat = 960

    /// One grid cell; a widget `span` cells wide is `span × cellWidth` points.
    let cellWidth: CGFloat
    let cardHeight: CGFloat

    func cardWidth(span: Int) -> CGFloat {
        CGFloat(span) * cellWidth
    }

    func openSize(for spans: [Int], closedHeight: CGFloat) -> CGSize {
        let cards = spans.map(cardWidth(span:)).reduce(0, +)
        let gaps = CGFloat(max(spans.count - 1, 0)) * Self.spacing
        let width = min(max(cards + gaps + Self.horizontalPadding * 2, Self.minOpenWidth), Self.maxOpenWidth)
        return CGSize(width: width, height: Self.openHeight(closedHeight: closedHeight, cardHeight: cardHeight))
    }

    /// The largest open notch any setting allows; the window is sized to it so resizing never recreates the window.
    static func maxOpenSize(closedHeight: CGFloat) -> CGSize {
        CGSize(
            width: maxOpenWidth,
            height: openHeight(closedHeight: closedHeight, cardHeight: AppearanceSettings.cardHeightRange.upperBound)
        )
    }

    private static func openHeight(closedHeight: CGFloat, cardHeight: CGFloat) -> CGFloat {
        closedHeight + topGap + cardHeight + bottomPadding
    }
}
