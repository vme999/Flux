import SwiftUI

// MARK: - Floating Liquid Glass tab bar (icon-only, compact)
struct FluxGlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Outer shell uses one continuous radius; inner track radius = outer − inset so curves stay parallel.
    private let outerCornerRadius: CGFloat = 22
    private let barEdgePadding: CGFloat = 6
    /// Stadium-shaped selection uses the same corner math as the shell (half-height rounding).
    private let tabRowMinHeight: CGFloat = 44

    private var innerTrackCornerRadius: CGFloat {
        max(12, outerCornerRadius - barEdgePadding)
    }

    private var spring: Animation {
        .spring(response: 0.38, dampingFraction: 0.9)
    }

    /// Soft “well” fill so it does not compete with the outer glass bar.
    private var selectionWellFillOpacity: Double {
        colorScheme == .dark ? 0.14 : 0.08
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(barEdgePadding)
        // Apply Liquid Glass in a background so layout follows the HStack’s intrinsic size.
        // A top-level `glassEffect` on the stack can expand to the full ZStack proposal (full screen).
        .background {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main tabs")
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            guard selection != tab else { return }
            if reduceMotion {
                selection = tab
            } else {
                withAnimation(spring) {
                    selection = tab
                }
            }
        } label: {
            Image(systemName: tab.tabBarSymbolName)
                .font(.system(size: isSelected ? 22 : 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .symbolVariant(isSelected ? .fill : .none)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: tabRowMinHeight)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: innerTrackCornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(selectionWellFillOpacity))
                            .overlay {
                                RoundedRectangle(cornerRadius: innerTrackCornerRadius, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                            }
                            .matchedGeometryEffect(id: "fluxTabSelection", in: selectionNamespace)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: innerTrackCornerRadius, style: .continuous))
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
