import SwiftUI

/// Floating Liquid Glass Pager Pill with Dynamic Alpha and Interactive Tracking:
/// - Fully opaque & prominent (alpha = 1.0) when touched, dragged, or immediately after page selection.
/// - Increases transparency during vertical scrolling (alpha ≈ 0.28) so underlying content is clearly visible.
/// - Rests at a subtle, elegant transparency (alpha ≈ 0.46) during idle states.
struct LocationLiquidGlassPagerPill: View {
    let pages: [WeatherStore.WeatherPageItem]
    let selectedIndex: Int
    var isScrolling: Bool = false
    let onSelectIndex: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isTouching: Bool = false
    @State private var isRecentActivity: Bool = false
    @State private var fadeTask: Task<Void, Never>? = nil

    // Dynamic alpha computed from usage states
    private var dynamicAlpha: Double {
        if isTouching {
            return 1.0
        } else if isRecentActivity {
            return 0.95
        } else if isScrolling {
            return 0.28
        } else {
            return 0.46
        }
    }

    private var borderAlpha: Double {
        if isTouching {
            return 0.70
        } else if isRecentActivity {
            return 0.50
        } else if isScrolling {
            return 0.15
        } else {
            return 0.28
        }
    }

    private var scaleMultiplier: Double {
        if isTouching {
            return 1.05
        } else if isScrolling {
            return 0.97
        } else {
            return 1.0
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                let isSelected = selectedIndex == index

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    triggerActivity()
                    onSelectIndex(index)
                } label: {
                    if page.isGPS {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                            .scaleEffect(isSelected ? 1.18 : 0.9)
                            .shadow(color: isSelected ? .white.opacity(0.8) : .clear, radius: 5)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
                    } else {
                        Circle()
                            .fill(isSelected ? Color.white : Color.white.opacity(0.4))
                            .frame(width: isSelected ? 7.5 : 5.5, height: isSelected ? 7.5 : 5.5)
                            .scaleEffect(isSelected ? 1.25 : 1.0)
                            .shadow(color: isSelected ? .white.opacity(0.75) : .clear, radius: 4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle().size(width: 24, height: 28))
                .accessibilityLabel(page.isGPS ? String(localized: "Current location") : page.name)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(borderAlpha),
                            .white.opacity(borderAlpha * 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .shadow(
            color: Color.black.opacity(isTouching ? 0.35 : 0.18),
            radius: isTouching ? 14 : 8,
            x: 0,
            y: isTouching ? 6 : 3
        )
        .scaleEffect(scaleMultiplier)
        .opacity(dynamicAlpha)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dynamicAlpha)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: scaleMultiplier)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isTouching {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isTouching = true
                        isRecentActivity = true
                        fadeTask?.cancel()
                    }
                }
                .onEnded { _ in
                    isTouching = false
                    scheduleFadeOut()
                }
        )
        .onChange(of: selectedIndex) { _, _ in
            triggerActivity()
        }
        .onAppear {
            triggerActivity()
        }
    }

    private func triggerActivity() {
        fadeTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isRecentActivity = true
        }
        scheduleFadeOut()
    }

    private func scheduleFadeOut() {
        fadeTask?.cancel()
        fadeTask = Task {
            try? await Task.sleep(for: .milliseconds(2200))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                isRecentActivity = false
            }
        }
    }
}
