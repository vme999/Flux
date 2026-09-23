import SwiftUI

struct TrendPageView: View {
    @ObservedObject var store: LedgerStore
    @Binding var tabBarHiddenByScroll: Bool
    @Binding var tabBarScrollHideSuppressUntil: Date?
    @State private var granularity: TrendGranularity = .month
    @State private var selectedSeries: TrendSeries = .expense
    /// Selected bar bucket for category ranking; `nil` uses the newest bucket in range until synced.
    @State private var selectedPeriodCategoryKey: String?
    /// Ranking list mode: expense vs income (default expense).
    @State private var rankRecordType: RecordType = .expense

    private var chartModel: TrendChartModel {
        LedgerTrendAggregation.chartModel(
            records: store.records,
            granularity: granularity,
            selectedSeries: selectedSeries
        )
    }

    private var selectedPeriodStartForRanking: Date {
        if let k = selectedPeriodCategoryKey,
           let bar = chartModel.bars.first(where: { $0.categoryKey == k }) {
            return bar.periodDate
        }
        return chartModel.bars.last?.periodDate ?? .now
    }

    private var categoryRankRows: [TrendCategoryRankRow] {
        LedgerTrendAggregation.categoryRankRows(
            records: store.records,
            periodStart: selectedPeriodStartForRanking,
            granularity: granularity,
            recordType: rankRecordType
        )
    }

    private var selectionPeriodLabel: String {
        LedgerTrendAggregation.selectionPeriodLabel(
            periodStart: selectedPeriodStartForRanking,
            granularity: granularity
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Picker("类型", selection: $selectedSeries) {
                            ForEach(TrendSeries.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("维度", selection: $granularity) {
                            ForEach(TrendGranularity.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)

                    ZStack(alignment: .top) {
                        TrendChartView(
                            model: chartModel,
                            granularity: granularity,
                            selectedSeries: selectedSeries,
                            scrollResetTrigger: store.records.count,
                            selectedCategoryKey: $selectedPeriodCategoryKey
                        )

                        if store.records.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "chart.bar")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("暂无数据")
                                    .font(.headline)
                                Text("先去添加几条记录，趋势图会自动生成。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                        }
                    }

                    if !store.records.isEmpty {
                        trendCategoryRankingSection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .fluxAutoHideTabBarOnVerticalScroll(
                isHidden: $tabBarHiddenByScroll,
                suppressHideUntil: $tabBarScrollHideSuppressUntil
            )
            .navigationTitle("趋势")
            .onAppear {
                syncSelectedPeriodCategoryKeyIfNeeded()
            }
            .onChange(of: granularity) { _, _ in
                syncSelectedPeriodCategoryKeyIfNeeded()
            }
            .onChange(of: store.records.count) { _, _ in
                syncSelectedPeriodCategoryKeyIfNeeded()
            }
        }
    }

    private var trendCategoryRankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类排行")
                .font(.headline)

            Text(selectionPeriodLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("排行类型", selection: $rankRecordType) {
                Text("支出排行").tag(RecordType.expense)
                Text("收入排行").tag(RecordType.income)
            }
            .pickerStyle(.segmented)

            if categoryRankRows.isEmpty {
                Text("该时段暂无\(rankRecordType.title)分类数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(categoryRankRows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(row.rank)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 28, alignment: .leading)
                            Text(row.categoryDisplay)
                                .font(.body)
                            Spacer(minLength: 8)
                            Text("\(row.amount, specifier: "%.1f")")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(rankRecordType == .income ? Color(uiColor: .systemGreen) : Color(uiColor: .systemRed))
                        }
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())

                        if index < categoryRankRows.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: TrendChartLayout.cardCornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Keeps selection on the newest bucket when unset or invalid (e.g. after changing granularity).
    private func syncSelectedPeriodCategoryKeyIfNeeded() {
        let keys = chartModel.bars.map(\.categoryKey)
        guard let newest = keys.last else {
            selectedPeriodCategoryKey = nil
            return
        }
        if let current = selectedPeriodCategoryKey, keys.contains(current) {
            return
        }
        selectedPeriodCategoryKey = newest
    }
}
