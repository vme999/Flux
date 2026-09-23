import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = LedgerStore()
    @State private var currentTab: AppTab = .ledger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusAmountInput = true
    @State private var keyboardVisible = false
    @State private var exportDocument = CSVDocument()
    @State private var showExporter = false

    /// Slashes in `defaultFilename` break the save path (e.g. locale numeric dates like `2025/3/23`).
    private static let exportFilenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    @State private var showImporter = false
    @State private var appError = ""
    @State private var showErrorAlert = false
    @State private var tabBarHiddenByScroll = false
    /// Ignores spurious scroll geometry right after a tab switch (set before child scroll views lay out).
    @State private var tabBarScrollHideSuppressUntil: Date?
    /// Last tab change indices (drives asymmetric slide transitions; set in `tabSelection` before `currentTab` updates).
    @State private var tabSwitchFromIndex: Int = 0
    @State private var tabSwitchToIndex: Int = 0

    /// Floating tab bar width as a fraction of the window width (see `safeAreaInset`).
    private let tabBarWidthFraction: CGFloat = 0.7

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { currentTab },
            set: { new in
                guard new != currentTab else { return }
                tabSwitchFromIndex = currentTab.tabBarIndex
                tabSwitchToIndex = new.tabBarIndex
                currentTab = new
                tabBarScrollHideSuppressUntil = Date().addingTimeInterval(0.4)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    tabBarHiddenByScroll = false
                }
            }
        )
    }

    var body: some View {
        GeometryReader { geo in
            tabContent
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !keyboardVisible && !tabBarHiddenByScroll {
                        HStack {
                            Spacer(minLength: 0)
                            FluxGlassTabBar(selection: tabSelection)
                                .frame(width: geo.size.width * tabBarWidthFraction)
                            Spacer(minLength: 0)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
        }
        .animation(.easeInOut(duration: 0.2), value: keyboardVisible)
        .animation(.easeInOut(duration: 0.22), value: tabBarHiddenByScroll)
        .sensoryFeedback(.selection, trigger: currentTab)
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "flux-records-\(Self.exportFilenameDateFormatter.string(from: Date()))"
            ) { result in
                if case .failure(let error) = result {
                    appError = "导出失败：\(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleImport(result)
            }
            .alert("操作失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(appError)
            }
            .onAppear {
                currentTab = .ledger
            }
    }

    private var tabContent: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                if currentTab == tab {
                    tabPage(for: tab)
                        .transition(
                            .asymmetric(
                                insertion: tabContentInsertionTransition,
                                removal: tabContentRemovalTransition
                            )
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(tabSwitchAnimation, value: currentTab)
    }

    private var tabSwitchAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private var tabContentInsertionTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = tabSwitchToIndex > tabSwitchFromIndex
        if forward {
            return .move(edge: .trailing).combined(with: .opacity)
        }
        return .move(edge: .leading).combined(with: .opacity)
    }

    private var tabContentRemovalTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = tabSwitchToIndex > tabSwitchFromIndex
        if forward {
            return .move(edge: .leading).combined(with: .opacity)
        }
        return .move(edge: .trailing).combined(with: .opacity)
    }

    @ViewBuilder
    private func tabPage(for tab: AppTab) -> some View {
        switch tab {
        case .ledger:
            LedgerPageView(
                store: store,
                focusAmountInput: $focusAmountInput,
                tabBarHiddenByScroll: $tabBarHiddenByScroll,
                tabBarScrollHideSuppressUntil: $tabBarScrollHideSuppressUntil,
                onManageKeyboard: { visible in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        keyboardVisible = visible
                    }
                }
            )
        case .trend:
            TrendPageView(
                store: store,
                tabBarHiddenByScroll: $tabBarHiddenByScroll,
                tabBarScrollHideSuppressUntil: $tabBarScrollHideSuppressUntil
            )
        case .manage:
            ManagePageView(
                store: store,
                tabBarHiddenByScroll: $tabBarHiddenByScroll,
                tabBarScrollHideSuppressUntil: $tabBarScrollHideSuppressUntil,
                onExport: {
                    exportDocument = CSVDocument(text: store.exportCSVText())
                    showExporter = true
                },
                onImport: {
                    showImporter = true
                }
            )
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let access = url.startAccessingSecurityScopedResource()
                defer {
                    if access { url.stopAccessingSecurityScopedResource() }
                }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw CocoaError(.fileReadInapplicableStringEncoding)
                }
                try store.importCSVText(text)
            } catch {
                appError = "导入失败：\(error.localizedDescription)"
                showErrorAlert = true
            }
        case .failure(let error):
            appError = "导入失败：\(error.localizedDescription)"
            showErrorAlert = true
        }
    }

}

#Preview {
    ContentView()
}
