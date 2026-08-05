import SwiftUI

/// Initial welcome / profile screen shown once before the dashboard.
/// The name is optional and stored locally on the device.
struct WelcomeView: View {
    @Bindable var store: WeatherStore

    @State private var name = ""
    @State private var appeared = false
    @FocusState private var nameFieldFocused: Bool
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

            VStack(spacing: 28) {
                Spacer()

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Welcome to DeepWeather")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Weather, beautifully animated.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Spacer()

                VStack(spacing: 14) {
                    TextField("Your name", text: $name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.25))
                        )
                        .foregroundStyle(.white)
                        .tint(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(start)

                    Button(action: start) {
                        Text("Start")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.15, green: 0.30, blue: 0.62))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)

                    Button {
                        store.completeWelcome(name: nil)
                    } label: {
                        Text("Continue without a name")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.vertical, 6)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
            .padding(28)
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func start() {
        nameFieldFocused = false
        store.completeWelcome(name: name)
    }
}
