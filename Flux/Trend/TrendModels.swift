import SwiftUI

enum TrendGranularity: String, CaseIterable, Identifiable {
    case day, month, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "日"
        case .month: return "月"
        case .year: return "年"
        }
    }

}

enum TrendSeries: String, CaseIterable, Identifiable {
    case income, expense, balance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "收入"
        case .expense: return "支出"
        case .balance: return "结余"
        }
    }

    var color: Color {
        switch self {
        case .income: return Color(uiColor: .systemGreen)
        case .expense: return Color(uiColor: .systemRed)
        case .balance: return .blue
        }
    }
}

struct TrendRow: Identifiable, Hashable {
    var id: Date { periodDate }
    let period: String
    let periodDate: Date
    let income: Double
    let expense: Double
    let balance: Double
}

struct ChartBar: Identifiable, Hashable {
    var id: Date { periodDate }
    /// Stable categorical X value for Swift Charts (avoids temporal `BarMark` / axis misalignment on the last bucket).
    let categoryKey: String
    let period: String
    let value: Double
    let periodDate: Date
}

/// Precomputed values for a single trend chart configuration (pure aggregation output).
struct TrendChartModel {
    let bars: [ChartBar]
    let yUpperBound: Double
    /// Categorical X domain in timeline order (must match `bars`).
    let xCategoryDomain: [String]
    let xAxisTickCategoryKeys: [String]
}

/// One row in the category ranking list for a selected trend period (amounts sorted descending).
struct TrendCategoryRankRow: Identifiable, Hashable {
    let rank: Int
    let categoryDisplay: String
    let amount: Double

    var id: String { "\(rank)-\(categoryDisplay)" }
}
