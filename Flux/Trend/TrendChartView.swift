import Charts
import SwiftUI

struct TrendChartView: View {
    let model: TrendChartModel
    let granularity: TrendGranularity
    let selectedSeries: TrendSeries
    /// Bumps horizontal scroll to the trailing edge when this value changes (e.g. record count).
    let scrollResetTrigger: Int
    /// Selected bar bucket (categorical X key); drives category ranking for that period.
    @Binding var selectedCategoryKey: String?

    private static let scrollEndID = "trendChartScrollEnd"

    var body: some View {
        GeometryReader { geo in
            let outerHPad = TrendChartLayout.horizontalOuterPadding
            let cardPad = TrendChartLayout.cardPadding
            let viewportW = max(geo.size.width - outerHPad * 2 - cardPad * 2, 1)
            let barSlotW = viewportW / TrendChartLayout.barSlotViewportDivisor
            let chartTotalW = max(barSlotW * CGFloat(model.bars.count), viewportW)
            let periodByCategoryKey = Dictionary(uniqueKeysWithValues: model.bars.map { ($0.categoryKey, $0.period) })

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 0) {
                        Chart(model.bars) { bar in
                            BarMark(
                                x: .value("周期", bar.categoryKey),
                                y: .value("金额", bar.value),
                                width: .ratio(TrendChartLayout.barMarkWidthRatio)
                            )
                            .foregroundStyle(selectedSeries.color)
                            .cornerRadius(TrendChartLayout.barMarkCornerRadius)
                            .annotation(position: bar.value >= 0 ? .top : .bottom, alignment: .center, spacing: 2) {
                                if bar.value != 0 {
                                    Text(Self.barAmountLabel(bar.value))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartYScale(domain: 0 ... model.yUpperBound)
                        .chartXScale(domain: model.xCategoryDomain)
                        .chartXSelection(value: $selectedCategoryKey)
                        .chartXAxis {
                            trendChartXAxisMarks(
                                keys: model.xAxisTickCategoryKeys,
                                periodByCategoryKey: periodByCategoryKey
                            )
                        }
                        .chartYAxis(.hidden)
                        .chartPlotStyle { plot in
                            plot
                                .padding(.horizontal, TrendChartLayout.chartPlotHorizontalPadding)
                                .padding(.bottom, TrendChartLayout.chartPlotBottomPadding)
                        }
                        .frame(width: chartTotalW, height: TrendChartLayout.chartLayoutHeight)
                        .padding(cardPad)
                        // Background only — avoid clipping X-axis labels at the rounded corners / fixed height.
                        .background {
                            RoundedRectangle(cornerRadius: TrendChartLayout.cardCornerRadius, style: .continuous)
                                .fill(.regularMaterial)
                        }

                        Color.clear
                            .frame(width: 1, height: 1)
                            .id(Self.scrollEndID)
                    }
                    .padding(.horizontal, outerHPad)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onAppear {
                    scrollTrendChartToTrailing(proxy: proxy)
                }
                .onChange(of: granularity) { _, _ in
                    scrollTrendChartToTrailing(proxy: proxy)
                }
                .onChange(of: scrollResetTrigger) { _, _ in
                    scrollTrendChartToTrailing(proxy: proxy)
                }
            }
        }
        .frame(height: TrendChartLayout.blockHeight)
        .frame(maxWidth: .infinity)
    }

    /// Bar-top labels: full amount when under 1k so small values are not shown as `0.0k`.
    private static func barAmountLabel(_ value: Double) -> String {
        let absV = abs(value)
        if absV < 1000 {
            return String(format: "%.1f", value)
        }
        let k = value / 1000
        return String(format: "%.1fk", k)
    }

    /// Snap horizontal scroll so the latest periods (right side) align with the trailing edge.
    private func scrollTrendChartToTrailing(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                proxy.scrollTo(Self.scrollEndID, anchor: .trailing)
            }
        }
    }

    @AxisContentBuilder
    private func trendChartXAxisMarks(keys: [String], periodByCategoryKey: [String: String]) -> some AxisContent {
        // Default marks sit on category edges while `BarMark` is centered in each band; `.aligned` centers marks on the bars.
        AxisMarks(preset: .aligned, values: keys) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(centered: true) {
                if let key = value.as(String.self) {
                    Text(periodByCategoryKey[key] ?? key)
                }
            }
        }
    }
}
