import SwiftUI

/// Animated gradient background: slow "breathing" highlight, drifting cloud
/// silhouette and optional twinkling stars at night. Respects Reduce Motion.
struct AnimatedWeatherBackgroundView: View {
    let gradient: [Color]
    let isNight: Bool
    var showsStars: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightOffset: CGFloat = -70
    @State private var cloudOffset: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

                if !reduceMotion {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: proxy.size.width * 0.75)
                        .blur(radius: 60)
                        .offset(x: highlightOffset, y: -highlightOffset * 0.55)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                                highlightOffset = 70
                            }
                        }

                    Image(systemName: "cloud.fill")
                        .font(.system(size: proxy.size.width * 0.95))
                        .foregroundStyle(.white.opacity(0.06))
                        .offset(x: cloudOffset, y: 30)
                        .onAppear {
                            withAnimation(.linear(duration: 24).repeatForever(autoreverses: true)) {
                                cloudOffset = -proxy.size.width * 0.7
                            }
                        }
                }

                if showsStars && !reduceMotion {
                    stars(in: proxy.size)
                }
            }
        }
    }

    private func stars(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 9 + CGFloat(index % 3) * 5))
                    .foregroundStyle(.white.opacity(0.55))
                    .symbolEffect(
                        .pulse,
                        options: .speed(0.6 + Double(index) * 0.2).repeating
                    )
                    .position(
                        x: size.width * (0.10 + 0.17 * CGFloat(index)),
                        y: size.height * (0.08 + 0.14 * CGFloat(index % 4))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
