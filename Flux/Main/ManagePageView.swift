import SwiftUI

struct ManagePageView: View {
    @ObservedObject var store: LedgerStore
    @Binding var tabBarHiddenByScroll: Bool
    @Binding var tabBarScrollHideSuppressUntil: Date?
    var onExport: () -> Void
    var onImport: () -> Void

    /// Drives List edit UI (minus, reorder). Toggled by the toolbar; bound into the List via environment.
    @State private var listEditMode = EditMode.inactive

    @State private var showCategorySheet = false
    @State private var categoryBeingEdited: CategoryItem?
    @State private var newType: RecordType = .expense
    @State private var newName = ""
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case name
    }

    private var canSaveCategory: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Fixed short detent for the one-field form; `.medium` / `.large` were unnecessarily tall.
    private let categoryEditorSheetDetentHeight: CGFloat = 160

    var body: some View {
        NavigationStack {
            // CSV lives in the same List so it scrolls with categories; rows opt out of delete/reorder in edit mode.
            List {
                categorySection(title: "收入分类", type: .income)
                categorySection(title: "支出分类", type: .expense)
                csvSection
            }
            .environment(\.editMode, $listEditMode)
            .fluxAutoHideTabBarOnVerticalScroll(
                isHidden: $tabBarHiddenByScroll,
                suppressHideUntil: $tabBarScrollHideSuppressUntil
            )
            .listStyle(.insetGrouped)
            .navigationTitle("管理")
            .toolbar {
                if listEditMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                listEditMode = .inactive
                            }
                        } label: {
                            Text("完成")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                listEditMode = .active
                            }
                        } label: {
                            Text("编辑")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCategorySheet, onDismiss: dismissCategorySheet) {
                categoryEditorSheet
            }
        }
    }

    private var csvSection: some View {
        Section {
            Button {
                onExport()
            } label: {
                HStack {
                    Text("导出全部记录到 CSV")
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .deleteDisabled(true)
            .moveDisabled(true)

            Button {
                onImport()
            } label: {
                HStack {
                    Text("从 CSV 导入记录")
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .deleteDisabled(true)
            .moveDisabled(true)
        } header: {
            Text("CSV")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private func categorySection(title: String, type: RecordType) -> some View {
        Section {
            let items = store.categories(for: type)
            if items.isEmpty {
                Text("暂无分类")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    Group {
                        if listEditMode == .active {
                            Button {
                                presentEditSheet(for: item)
                            } label: {
                                Text(item.name)
                            }
                        } else {
                            Text(item.name)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .deleteDisabled(listEditMode != .active)
                    .moveDisabled(listEditMode != .active)
                }
                .onDelete { offsets in
                    deleteCategories(at: offsets, type: type)
                }
                .onMove { source, destination in
                    store.moveCategory(from: source, to: destination, type: type)
                }
            }
            if listEditMode == .active {
                Button {
                    presentAddSheet(for: type)
                } label: {
                    Label(type == .income ? "添加收入分类" : "添加支出分类", systemImage: "plus")
                }
                .deleteDisabled(true)
                .moveDisabled(true)
            }
        } header: {
            Text(title)
        }
    }

    private func deleteCategories(at offsets: IndexSet, type: RecordType) {
        let snapshot = store.categories(for: type)
        let idsToRemove = offsets.map { snapshot[$0].id }
        for id in idsToRemove {
            store.removeCategory(id: id)
        }
    }

    private func presentAddSheet(for type: RecordType) {
        categoryBeingEdited = nil
        newType = type
        newName = ""
        showCategorySheet = true
    }

    private func presentEditSheet(for item: CategoryItem) {
        categoryBeingEdited = item
        newType = item.type
        newName = item.name
        showCategorySheet = true
    }

    private func dismissCategorySheet() {
        categoryBeingEdited = nil
        resetForm()
    }

    private var categoryEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $newName)
                        .focused($focusedField, equals: .name)
                } header: {
                    Text("分类信息")
                }
            }
            .navigationTitle(categoryBeingEdited == nil ? "新增分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCategorySheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(categoryBeingEdited == nil ? "添加" : "完成") {
                        if let editing = categoryBeingEdited {
                            store.updateCategory(id: editing.id, name: newName)
                        } else {
                            store.addCategory(name: newName, type: newType)
                        }
                        showCategorySheet = false
                    }
                    .disabled(!canSaveCategory)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
        .presentationDetents([.height(categoryEditorSheetDetentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func resetForm() {
        newType = .expense
        newName = ""
    }
}
