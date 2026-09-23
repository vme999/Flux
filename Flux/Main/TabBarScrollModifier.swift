import SwiftUI

// MARK: - Tab bar visibility from vertical scroll
@available(iOS 18.0, *)
struct FluxAutoHideTabBarScrollModifier: ViewModifier {
    @Binding var isTabBarHiddenByScroll: Bool
    /// While non-nil and in the future, ignore scroll-driven hide (avoids layout glitches after tab switches).
    @Binding var suppressHideUntil: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastContentOffsetY: CGFloat?
    @State private var showTabBarAfterIdleTask: Task<Void, Never>?

    /// After scrolling stops, show the tab bar again (hide only applies while actively scrolling down).
    private static let idleShowDelayNanoseconds: UInt64 = 300_000_000

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newY in
                scheduleShowTabBarWhenScrollIdle()

                guard let oldY = lastContentOffsetY else {
                    lastContentOffsetY = newY
                    return
                }
                lastContentOffsetY = newY
                let delta = oldY - newY
                guard abs(delta) >= 4 else { return }

                if let until = suppressHideUntil, Date() < until {
                    return
                }

                // Finger moves up → content moves up → offset increases → hide chrome.
                let shouldHide = delta > 0
                guard shouldHide != isTabBarHiddenByScroll else { return }

                if reduceMotion {
                    isTabBarHiddenByScroll = shouldHide
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isTabBarHiddenByScroll = shouldHide
                    }
                }
            }
            .onDisappear {
                showTabBarAfterIdleTask?.cancel()
                showTabBarAfterIdleTask = nil
            }
    }

    private func scheduleShowTabBarWhenScrollIdle() {
        showTabBarAfterIdleTask?.cancel()
        showTabBarAfterIdleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.idleShowDelayNanoseconds)
            guard !Task.isCancelled else { return }
            if reduceMotion {
                isTabBarHiddenByScroll = false
            } else {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isTabBarHiddenByScroll = false
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func fluxAutoHideTabBarOnVerticalScroll(
        isHidden: Binding<Bool>,
        suppressHideUntil: Binding<Date?> = .constant(nil)
    ) -> some View {
        if #available(iOS 18.0, *) {
            modifier(FluxAutoHideTabBarScrollModifier(
                isTabBarHiddenByScroll: isHidden,
                suppressHideUntil: suppressHideUntil
            ))
        } else {
            self
        }
    }
}
