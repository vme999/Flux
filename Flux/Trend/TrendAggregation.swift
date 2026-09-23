import Foundation

/// Pure ledger → timeline → chart transforms (no SwiftUI).
enum LedgerTrendAggregation {

    static func groupedRows(
        records: [LedgerRecord],
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> [TrendRow] {
        let grouped = Dictionary(grouping: records) { record -> Date in
            switch granularity {
            case .day:
                return calendar.startOfDay(for: record.time)
            case .month:
                let comps = calendar.dateComponents([.year, .month], from: record.time)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: record.time)
            case .year:
                let comps = calendar.dateComponents([.year], from: record.time)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: record.time)
            }
        }
        return grouped.map { key, items in
            let income = items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expense = items.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let label = trendPeriodLabel(for: key, granularity: granularity, calendar: calendar)
            return TrendRow(period: label, periodDate: key, income: income, expense: expense, balance: income - expense)
        }
        .sorted { $0.periodDate < $1.periodDate }
    }

    /// Scrollable timeline bounds: day = last `TrendChartLayout.dayRollingWindowDayCount` days ending today; month/year = 12 buckets ending at the current month/year.
    static func chartSpanBounds(
        granularity: TrendGranularity,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (oldest: Date, newest: Date)? {
        switch granularity {
        case .day:
            let today = calendar.startOfDay(for: now)
            let back = TrendChartLayout.dayRollingWindowDayCount - 1
            guard let oldest = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (oldest, today)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: now)
            guard let thisMonthStart = calendar.date(from: comps) else { return nil }
            guard let oldest = calendar.date(byAdding: .month, value: -11, to: thisMonthStart) else { return nil }
            return (oldest, thisMonthStart)
        case .year:
            let y = calendar.component(.year, from: now)
            guard let newest = calendar.date(from: DateComponents(year: y)) else { return nil }
            guard let oldest = calendar.date(from: DateComponents(year: y - 11)) else { return nil }
            return (oldest, newest)
        }
    }

    static func normalizeTrendPeriodStart(
        _ date: Date,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> Date {
        switch granularity {
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        case .year:
            let y = calendar.component(.year, from: date)
            return calendar.date(from: DateComponents(year: y)) ?? calendar.startOfDay(for: date)
        }
    }

    static func advancedTrendPeriod(
        _ start: Date,
        by step: Int,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> Date? {
        switch granularity {
        case .day:
            return calendar.date(byAdding: .day, value: step, to: start)
        case .month:
            return calendar.date(byAdding: .month, value: step, to: start)
        case .year:
            return calendar.date(byAdding: .year, value: step, to: start)
        }
    }

    /// Every period from `oldest` through `newest` (inclusive), oldest → newest.
    static func generateTrendPeriodStarts(
        from oldest: Date,
        through newest: Date,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> [Date] {
        let o = normalizeTrendPeriodStart(oldest, granularity: granularity, calendar: calendar)
        let n = normalizeTrendPeriodStart(newest, granularity: granularity, calendar: calendar)
        guard o <= n else { return [] }
        var out: [Date] = []
        var current: Date? = o
        while let d = current, d <= n {
            out.append(d)
            guard let next = advancedTrendPeriod(d, by: 1, granularity: granularity, calendar: calendar), next > d else { break }
            current = next
        }
        return out
    }

    /// Short labels for chart X-axis: day → `dd`, month → `mm`, year → `yyyy` (numeric, fixed width).
    static func trendPeriodLabel(for periodStart: Date, granularity: TrendGranularity, calendar: Calendar = .current) -> String {
        switch granularity {
        case .day:
            let d = calendar.component(.day, from: periodStart)
            return String(format: "%02d", d)
        case .month:
            let m = calendar.component(.month, from: periodStart)
            return String(format: "%02d", m)
        case .year:
            let y = calendar.component(.year, from: periodStart)
            return String(format: "%04d", y)
        }
    }

    /// Sortable, unique key per bucket for categorical chart X (not shown to the user).
    static func chartCategoryKey(
        for periodStart: Date,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> String {
        switch granularity {
        case .day:
            let d = normalizeTrendPeriodStart(periodStart, granularity: .day, calendar: calendar)
            let y = calendar.component(.year, from: d)
            let m = calendar.component(.month, from: d)
            let day = calendar.component(.day, from: d)
            return String(format: "%04d-%02d-%02d", y, m, day)
        case .month:
            let d = normalizeTrendPeriodStart(periodStart, granularity: .month, calendar: calendar)
            let y = calendar.component(.year, from: d)
            let m = calendar.component(.month, from: d)
            return String(format: "%04d-%02d", y, m)
        case .year:
            let d = normalizeTrendPeriodStart(periodStart, granularity: .year, calendar: calendar)
            let y = calendar.component(.year, from: d)
            return String(format: "%04d", y)
        }
    }

    /// Full timeline within fixed span (day = rolling window; month/year = 12 buckets), expanded to include any ledger data outside that window so bars are not all zero.
    static func chartTimelineRows(
        groupedRows: [TrendRow],
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> [TrendRow] {
        guard let span = chartSpanBounds(granularity: granularity, calendar: calendar) else { return [] }

        var spanOldest = normalizeTrendPeriodStart(span.oldest, granularity: granularity, calendar: calendar)
        var spanNewest = normalizeTrendPeriodStart(span.newest, granularity: granularity, calendar: calendar)

        if let dataMin = groupedRows.map(\.periodDate).min(),
           let dataMax = groupedRows.map(\.periodDate).max() {
            let nMin = normalizeTrendPeriodStart(dataMin, granularity: granularity, calendar: calendar)
            let nMax = normalizeTrendPeriodStart(dataMax, granularity: granularity, calendar: calendar)
            spanOldest = min(spanOldest, nMin)
            spanNewest = max(spanNewest, nMax)
        }

        let lookup: [Date: TrendRow] = Dictionary(
            uniqueKeysWithValues: groupedRows.compactMap { row -> (Date, TrendRow)? in
                let k = normalizeTrendPeriodStart(row.periodDate, granularity: granularity, calendar: calendar)
                guard k >= spanOldest, k <= spanNewest else { return nil }
                return (k, row)
            }
        )

        let starts = generateTrendPeriodStarts(from: spanOldest, through: spanNewest, granularity: granularity, calendar: calendar)
        return starts.map { start in
            if let row = lookup[start] {
                return row
            }
            return TrendRow(
                period: trendPeriodLabel(for: start, granularity: granularity, calendar: calendar),
                periodDate: start,
                income: 0,
                expense: 0,
                balance: 0
            )
        }
    }

    static func chartBars(
        from timeline: [TrendRow],
        selectedSeries: TrendSeries,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> [ChartBar] {
        timeline.map { row in
            let value: Double
            switch selectedSeries {
            case .income: value = row.income
            case .expense: value = row.expense
            case .balance: value = row.balance
            }
            let key = chartCategoryKey(for: row.periodDate, granularity: granularity, calendar: calendar)
            return ChartBar(
                categoryKey: key,
                period: row.period,
                value: value,
                periodDate: row.periodDate
            )
        }
    }

    static func chartYUpperBound(for bars: [ChartBar]) -> Double {
        let m = bars.map(\.value).max() ?? 0
        if m <= 0 { return TrendChartLayout.yAxisFloorWhenEmpty }
        return m * TrendChartLayout.yAxisMaxMultiplier
    }

    /// Subsample categorical X keys for axis labels; always includes the first and newest bucket.
    static func trendChartXAxisTickCategoryKeys(for bars: [ChartBar]) -> [String] {
        let keys = bars.map(\.categoryKey)
        guard !keys.isEmpty else { return [] }
        guard keys.count > 1 else { return keys }
        let maxLabels = TrendChartLayout.xAxisMaxLabels
        let step = max(1, (keys.count - 1) / max(maxLabels - 1, 1))
        var out: [String] = []
        var i = 0
        while i < keys.count {
            out.append(keys[i])
            i += step
        }
        if let first = keys.first, out.first != first {
            out.insert(first, at: 0)
        }
        if let last = keys.last, out.last != last {
            out.append(last)
        }
        return out
    }

    static func chartModel(
        records: [LedgerRecord],
        granularity: TrendGranularity,
        selectedSeries: TrendSeries,
        calendar: Calendar = .current
    ) -> TrendChartModel {
        let grouped = groupedRows(records: records, granularity: granularity, calendar: calendar)
        let timeline = chartTimelineRows(groupedRows: grouped, granularity: granularity, calendar: calendar)
        let bars = chartBars(from: timeline, selectedSeries: selectedSeries, granularity: granularity, calendar: calendar)
        let y = chartYUpperBound(for: bars)
        let categoryDomain = bars.map(\.categoryKey)
        let tickKeys = trendChartXAxisTickCategoryKeys(for: bars)
        return TrendChartModel(bars: bars, yUpperBound: y, xCategoryDomain: categoryDomain, xAxisTickCategoryKeys: tickKeys)
    }

    /// Human-readable label for the bar / ranking period (follows current locale).
    static func selectionPeriodLabel(
        periodStart: Date,
        granularity: TrendGranularity,
        calendar: Calendar = .current
    ) -> String {
        let d = normalizeTrendPeriodStart(periodStart, granularity: granularity, calendar: calendar)
        switch granularity {
        case .day:
            return d.formatted(.dateTime.year().month().day())
        case .month:
            return d.formatted(.dateTime.year().month())
        case .year:
            return d.formatted(.dateTime.year())
        }
    }

    /// Per-category totals for one trend bucket, income or expense only, sorted by amount descending.
    static func categoryRankRows(
        records: [LedgerRecord],
        periodStart: Date,
        granularity: TrendGranularity,
        recordType: RecordType,
        calendar: Calendar = .current
    ) -> [TrendCategoryRankRow] {
        let normalized = normalizeTrendPeriodStart(periodStart, granularity: granularity, calendar: calendar)
        let filtered = records.filter { record in
            guard record.type == recordType else { return false }
            let bucket = normalizeTrendPeriodStart(record.time, granularity: granularity, calendar: calendar)
            return bucket == normalized
        }
        var sums: [String: Double] = [:]
        for record in filtered {
            let key = record.categoryName
            sums[key, default: 0] += record.amount
        }
        let sorted = sums.sorted { $0.value > $1.value }
        return sorted.enumerated().map { index, pair in
            TrendCategoryRankRow(rank: index + 1, categoryDisplay: pair.key, amount: pair.value)
        }
    }
}
