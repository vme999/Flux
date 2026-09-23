import CoreGraphics

/// Shared layout metrics for the trend bar chart surface.
enum TrendChartLayout {
    /// Total height for the `Chart` (plot + X-axis labels). Slightly taller than before so bottom labels are not clipped.
    static let chartLayoutHeight: CGFloat = 312
    /// Extra vertical space reserved under the chart (scroll / safe layout).
    static let verticalChromeBelowChart: CGFloat = 24
    static var blockHeight: CGFloat { chartLayoutHeight + verticalChromeBelowChart }

    static let horizontalOuterPadding: CGFloat = 16
    static let cardPadding: CGFloat = 12

    /// Bar column width baseline: `viewportW / barSlotViewportDivisor` (≈ four bars visible without horizontal scroll).
    static let barSlotViewportDivisor: CGFloat = 4

    /// Rolling day span length (inclusive of today) for day-granularity trend chart.
    static let dayRollingWindowDayCount: Int = 31

    static let barMarkCornerRadius: CGFloat = 4
    static let barMarkWidthRatio: CGFloat = 0.72

    static let chartPlotBottomPadding: CGFloat = 4
    /// Insets the plot so first/last X labels are less likely to clip against the card or collide with Y-axis values.
    static let chartPlotHorizontalPadding: CGFloat = 8
    static let cardCornerRadius: CGFloat = 16

    /// Headroom above the tallest bar for Y scale and bar-top value labels.
    static let yAxisMaxMultiplier: Double = 1.2
    static let yAxisFloorWhenEmpty: Double = 1

    /// Max X axis labels; indices sampled so the newest period stays labeled.
    static let xAxisMaxLabels: Int = 8
}
