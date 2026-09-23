import SwiftUI

struct LedgerPageView: View {
    @ObservedObject var store: LedgerStore
    @Binding var focusAmountInput: Bool
    @Binding var tabBarHiddenByScroll: Bool
    @Binding var tabBarScrollHideSuppressUntil: Date?
    var onManageKeyboard: (Bool) -> Void

    @State private var recordType: RecordType = .expense
    @State private var selectedCategoryID: UUID?
    @State private var amountText = ""
    @State private var recordDate = Date()
    @State private var showInputMode = false
    @FocusState private var amountFieldFocused: Bool

    private var availableCategories: [CategoryItem] {
        store.categories(for: recordType)
    }

    private var selectedCategory: CategoryItem? {
        if let selectedCategoryID,
           let category = availableCategories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }
        return availableCategories.first
    }

    private var normalizedAmountString: String {
        amountText.replacingOccurrences(of: ",", with: ".")
    }

    private var parsedAmount: Double? {
        let s = normalizedAmountString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        return Double(s)
    }

    /// True when the user entered something in the amount field but it cannot be saved as a positive value.
    private var amountFieldShowsValidationHint: Bool {
        let trimmed = normalizedAmountString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let a = parsedAmount, a > 0 else { return true }
        return false
    }

    private var canSaveRecord: Bool {
        guard selectedCategory != nil, !availableCategories.isEmpty else { return false }
        guard let a = parsedAmount, a > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            List {
                if showInputMode {
                    Section("快速记账") {
                        inputCard
                    }
                }

                Section {
                    if store.sortedRecords.isEmpty {
                        Text("暂无记录，先添加一条吧。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(store.sortedRecords.prefix(20)) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.categoryName)
                                        .font(.body.weight(.medium))
                                    Text(record.time, format: .dateTime.year().month(.abbreviated).day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(record.type == .income ? "+" : "-")\(record.amount, specifier: "%.1f")")
                                    .font(.headline)
                                    .foregroundStyle(record.type == .income ? Color(uiColor: .systemGreen) : Color(uiColor: .systemRed))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.removeRecord(id: record.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .fluxAutoHideTabBarOnVerticalScroll(
                isHidden: $tabBarHiddenByScroll,
                suppressHideUntil: $tabBarScrollHideSuppressUntil
            )
            .navigationTitle("记账")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showInputMode.toggle()
                            if showInputMode {
                                amountFieldFocused = true
                            } else {
                                amountFieldFocused = false
                            }
                        }
                    } label: {
                        Image(systemName: showInputMode ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
        .onAppear {
            if selectedCategoryID == nil {
                selectedCategoryID = availableCategories.first?.id
            }
        }
        .onChange(of: recordType) { _, _ in
            selectedCategoryID = availableCategories.first?.id
        }
        .onChange(of: focusAmountInput) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showInputMode = true
                    amountFieldFocused = true
                    focusAmountInput = false
                }
            }
        }
        .onChange(of: amountFieldFocused) { _, focused in
            onManageKeyboard(focused)
        }
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            Picker("类型", selection: $recordType) {
                ForEach(RecordType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // List often hides `Picker` labels; keep an explicit row so category selection is obvious.
            HStack(alignment: .center, spacing: 12) {
                Text("分类")
                    .font(.body)
                Spacer(minLength: 8)
                if availableCategories.isEmpty {
                    Text("请先在「管理」中添加")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    Picker("分类", selection: $selectedCategoryID) {
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 120, alignment: .trailing)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 12) {
                    Text("金额")
                        .font(.body)
                    Spacer(minLength: 8)
                    TextField("1位小数", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($amountFieldFocused)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160, alignment: .trailing)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())

                if amountFieldShowsValidationHint {
                    Text("请输入大于 0 的合法金额")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DatePicker("时间", selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)

            Button {
                addRecord()
            } label: {
                Text("保存记录")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSaveRecord)
        }
        .padding(.vertical, 8)
    }

    private func addRecord() {
        guard canSaveRecord, let category = selectedCategory else { return }
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized.trimmingCharacters(in: .whitespacesAndNewlines)), amount > 0 else { return }
        let oneDecimal = (amount * 10).rounded() / 10
        store.addRecord(type: recordType, category: category, amount: oneDecimal, time: recordDate)
        amountText = ""
        recordDate = Date()
        amountFieldFocused = true
    }
}
