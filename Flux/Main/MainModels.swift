import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Enums
enum RecordType: String, Codable, CaseIterable, Identifiable {
    case income, expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "收入"
        case .expense: return "支出"
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case ledger, trend, manage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ledger: return "记账"
        case .trend: return "趋势"
        case .manage: return "管理"
        }
    }

    /// SF Symbol used by the floating glass tab bar (filled via `symbolVariant` when selected).
    var tabBarSymbolName: String {
        switch self {
        case .ledger: return "square.and.pencil"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .manage: return "gearshape"
        }
    }

    /// Order in the bottom tab strip (for directional page transitions).
    var tabBarIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - Data Models
struct CategoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: RecordType

    enum CodingKeys: String, CodingKey {
        case id, name, type, emoji
    }

    init(id: UUID, name: String, type: RecordType) {
        self.id = id
        self.name = name
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(RecordType.self, forKey: .type)
        _ = try? container.decode(String.self, forKey: .emoji)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
    }
}

struct LedgerRecord: Codable, Identifiable {
    let id: UUID
    var type: RecordType
    var categoryName: String
    var amount: Double
    /// When the transaction occurred (date and time, local calendar).
    var time: Date

    enum CodingKeys: String, CodingKey {
        case id, type, categoryName, amount, time, recordedAt, categoryEmoji
    }

    init(id: UUID, type: RecordType, categoryName: String, amount: Double, time: Date) {
        self.id = id
        self.type = type
        self.categoryName = categoryName
        self.amount = amount
        self.time = time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(RecordType.self, forKey: .type)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        amount = try container.decode(Double.self, forKey: .amount)
        var decodedTime = try container.decode(Date.self, forKey: .time)
        // Legacy: `time` was start-of-day only; real ordering used `recordedAt`.
        if let recordedAt = try container.decodeIfPresent(Date.self, forKey: .recordedAt) {
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: decodedTime)
            if decodedTime == startOfDay && recordedAt != startOfDay {
                decodedTime = recordedAt
            }
        }
        time = decodedTime
        _ = try? container.decode(String.self, forKey: .categoryEmoji)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(amount, forKey: .amount)
        try container.encode(time, forKey: .time)
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            text = decoded
            return
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}
