import SwiftUI

struct SplashView: View {
    @State private var animated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AnimatedWeatherBackgroundView(
                gradient: [
                    Color(red: 0.35, green: 0.62, blue: 0.95),
                    Color(red: 0.24, green: 0.45, blue: 0.85),
                    Color(red: 0.15, green: 0.30, blue: 0.62)
                ],
                isNight: false
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(animated ? 1 : 0.7)
                    .opacity(animated ? 1 : 0)

                Text("DeepWeather")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(animated ? 1 : 0)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                animated = true
                return
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animated = true
            }
        }
    }
}
