import SwiftUI

struct AnimatedWeatherIconView: View {
    let symbol: String
    let kind: WeatherAnimationKind
    let accessibilityLabel: String
    var foregroundColor: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var cloudDrift = false

    var body: some View {
        Group {
            if reduceMotion {
                baseIcon
            } else {
                switch kind {
                case .sun, .moon:
                    baseIcon
                        .symbolEffect(.pulse, options: .repeating)
                case .rain, .snow:
                    baseIcon
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                case .storm:
                    baseIcon
                        .symbolEffect(.variableColor, options: .repeating)
                case .cloud:
                    baseIcon
                        .offset(x: cloudDrift ? -6 : 6)
                case .fog:
                    baseIcon
                        .symbolEffect(.variableColor.iterative, options: .speed(0.5).repeating)
                }
            }
        }
        .scaleEffect(reduceMotion ? 1 : (breathing ? 1.05 : 0.97))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                cloudDrift = true
            }
        }
        .id("\(symbol)-\(kind)")
        .accessibilityLabel(accessibilityLabel)
    }

    private var baseIcon: some View {
        Image(systemName: symbol)
            .font(.system(size: 60, weight: .light))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(foregroundColor)
    }
}
