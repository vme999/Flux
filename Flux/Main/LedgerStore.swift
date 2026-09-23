import Combine
import Foundation

final class LedgerStore: ObservableObject {
    @Published var records: [LedgerRecord] = [] { didSet { save() } }
    @Published var categories: [CategoryItem] = [] { didSet { save() } }

    /// While true, `didSet` persistence is skipped so loading `records` cannot overwrite `categories.json` (and vice versa) with stale empty data.
    private var isLoadingFromDisk = false

    /// Legacy keys; data is migrated once to Application Support JSON files.
    private static let legacyRecordsKey = "flux.records.v1"
    private static let legacyCategoriesKey = "flux.categories.v1"

    private static let recordsFileName = "records.json"
    private static let categoriesFileName = "categories.json"

    init() {
        load()
    }

    private var storageDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Flux", isDirectory: true)
    }

    private var recordsFileURL: URL {
        storageDirectoryURL.appendingPathComponent(Self.recordsFileName, isDirectory: false)
    }

    private var categoriesFileURL: URL {
        storageDirectoryURL.appendingPathComponent(Self.categoriesFileName, isDirectory: false)
    }

    private func ensureStorageDirectory() {
        try? FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
    }

    var sortedRecords: [LedgerRecord] {
        records.sorted { $0.time > $1.time }
    }

    func categories(for type: RecordType) -> [CategoryItem] {
        categories.filter { $0.type == type }
    }

    func addRecord(type: RecordType, category: CategoryItem, amount: Double, time: Date) {
        let normalized = (amount * 10).rounded() / 10
        let item = LedgerRecord(
            id: UUID(),
            type: type,
            categoryName: category.name,
            amount: normalized,
            time: time
        )
        records.append(item)
    }

    func addCategory(name: String, type: RecordType) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        categories.append(CategoryItem(id: UUID(), name: cleanedName, type: type))
    }

    func updateCategory(id: UUID, name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].name = cleanedName
    }

    func removeCategory(id: UUID) {
        categories.removeAll { $0.id == id }
    }

    func removeRecord(id: UUID) {
        records.removeAll { $0.id == id }
    }

    /// Reorders categories of one `RecordType` while preserving the relative order of other types in storage.
    func moveCategory(from source: IndexSet, to destination: Int, type: RecordType) {
        var reordered = categories.filter { $0.type == type }
        reordered.move(fromOffsets: source, toOffset: destination)
        var iterator = reordered.makeIterator()
        categories = categories.map { category in
            if category.type == type {
                return iterator.next() ?? category
            }
            return category
        }
    }

    func exportCSVText() -> String {
        let header = "id,type,categoryName,amount,time\n"
        let body = sortedRecords.map { record in
            let id = record.id.uuidString
            let type = record.type.rawValue
            let name = csvEscaped(record.categoryName)
            let amount = String(format: "%.1f", record.amount)
            let time = ISO8601DateFormatter().string(from: record.time)
            return "\(id),\(type),\(name),\(amount),\(time)"
        }.joined(separator: "\n")
        return header + body
    }

    func importCSVText(_ text: String) throws {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return }

        let formatter = ISO8601DateFormatter()
        var imported: [LedgerRecord] = []
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            let parsed = parseCSVRecordFields(fields)
            guard let id = parsed.id,
                  let type = parsed.type,
                  let amount = parsed.amount,
                  let time = formatter.date(from: parsed.timeString) else {
                continue
            }
            let item = LedgerRecord(
                id: id,
                type: type,
                categoryName: parsed.categoryName,
                amount: (amount * 10).rounded() / 10,
                time: time
            )
            imported.append(item)
        }
        records = imported.sorted { $0.time > $1.time }
    }

    private func load() {
        isLoadingFromDisk = true
        defer { isLoadingFromDisk = false }

        ensureStorageDirectory()
        let decoder = JSONDecoder()
        let fm = FileManager.default
        let defaults = UserDefaults.standard

        var migratedFromUserDefaults = false

        if fm.fileExists(atPath: recordsFileURL.path),
           let data = try? Data(contentsOf: recordsFileURL),
           let decoded = try? decoder.decode([LedgerRecord].self, from: data) {
            records = decoded
        } else if let data = defaults.data(forKey: Self.legacyRecordsKey),
                  let decoded = try? decoder.decode([LedgerRecord].self, from: data) {
            records = decoded
            migratedFromUserDefaults = true
        }

        if fm.fileExists(atPath: categoriesFileURL.path),
           let data = try? Data(contentsOf: categoriesFileURL),
           let decoded = try? decoder.decode([CategoryItem].self, from: data) {
            categories = decoded
        } else if let data = defaults.data(forKey: Self.legacyCategoriesKey),
                  let decoded = try? decoder.decode([CategoryItem].self, from: data),
                  !decoded.isEmpty {
            categories = decoded
            migratedFromUserDefaults = true
        } else {
            categories = []
        }

        if migratedFromUserDefaults {
            writeJSONFiles()
            defaults.removeObject(forKey: Self.legacyRecordsKey)
            defaults.removeObject(forKey: Self.legacyCategoriesKey)
        }
    }

    /// Persists `records` and `categories` as JSON under Application Support/Flux/.
    private func writeJSONFiles() {
        ensureStorageDirectory()
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(records) {
            try? data.write(to: recordsFileURL, options: .atomic)
        }
        if let data = try? encoder.encode(categories) {
            try? data.write(to: categoriesFileURL, options: .atomic)
        }
    }

    private func save() {
        guard !isLoadingFromDisk else { return }
        writeJSONFiles()
    }

    /// Supports current CSV (`id,type,categoryName,amount,time`), legacy with emoji column, and headerless rows.
    private func parseCSVRecordFields(_ fields: [String]) -> (id: UUID?, type: RecordType?, categoryName: String, amount: Double?, timeString: String) {
        let trimmed = fields.map { $0.trimmingCharacters(in: .whitespaces) }

        switch trimmed.count {
        case 6...:
            // Legacy: id, type, categoryEmoji, categoryName, amount, time
            let idString = trimmed[0]
            let id: UUID
            if idString.isEmpty {
                id = UUID()
            } else if let parsed = UUID(uuidString: idString) {
                id = parsed
            } else {
                id = UUID()
            }
            let type = RecordType(rawValue: trimmed[1])
            let categoryName = trimmed[3]
            let amount = Double(trimmed[4])
            let timeString = trimmed[5]
            return (id, type, categoryName, amount, timeString)

        case 5:
            let first = trimmed[0]
            if let uuid = UUID(uuidString: first) {
                // New: id, type, categoryName, amount, time
                let type = RecordType(rawValue: trimmed[1])
                let categoryName = trimmed[2]
                let amount = Double(trimmed[3])
                let timeString = trimmed[4]
                return (uuid, type, categoryName, amount, timeString)
            } else {
                // Legacy without id: type, categoryEmoji, categoryName, amount, time
                let type = RecordType(rawValue: trimmed[0])
                let categoryName = trimmed[2]
                let amount = Double(trimmed[3])
                let timeString = trimmed[4]
                return (UUID(), type, categoryName, amount, timeString)
            }

        case 4:
            // New without id: type, categoryName, amount, time
            let type = RecordType(rawValue: trimmed[0])
            let categoryName = trimmed[1]
            let amount = Double(trimmed[2])
            let timeString = trimmed[3]
            return (UUID(), type, categoryName, amount, timeString)

        default:
            return (nil, nil, "", nil, "")
        }
    }

    private func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}
