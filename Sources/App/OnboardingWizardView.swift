import SwiftUI

/// Streamlined 2-step onboarding wizard for first launch or setup restart:
/// Step 1: Location choice (Search city or GPS)
/// Step 2: Preferences (Units °C/°F and optional notifications)
struct OnboardingWizardView: View {
    @Bindable var store: WeatherStore
    var locationManager: LocationManager

    enum Step: Int, CaseIterable {
        case location = 0
        case preferences = 1
    }

    @State private var currentStep: Step = .location
    @State private var searchQuery: String = ""
    @State private var searchResults: [GeoResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCity: GeoResult?
    @State private var useGPS: Bool = false
    @State private var isRequestingGPS: Bool = false

    @State private var useMetric: Bool = true
    @State private var dailySummary: Bool = false

    @FocusState private var searchFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let geocodingClient = GeocodingClient()

    var body: some View {
        ZStack {
            // Background dynamic atmosphere
            AnimatedWeatherBackgroundView(
                gradient: [
                    Color(red: 0.35, green: 0.62, blue: 0.95),
                    Color(red: 0.20, green: 0.46, blue: 0.85),
                    Color(red: 0.12, green: 0.30, blue: 0.68)
                ],
                isNight: false
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with step indicators and back button
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer(minLength: 12)

                // Current step content
                Group {
                    switch currentStep {
                    case .location:
                        locationStepView
                    case .preferences:
                        preferencesStepView
                    }
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                )

                Spacer(minLength: 16)

                // Bottom Action button
                bottomActionBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentStep)
        .onAppear {
            useMetric = store.useMetric
            dailySummary = store.dailySummaryEnabled
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            if currentStep != .location {
                Button {
                    previousStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(String(localized: "Back"))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            // Step dots
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step == currentStep ? Color.white : Color.white.opacity(0.35))
                        .frame(width: step == currentStep ? 22 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }

            Spacer()

            Spacer().frame(width: 60)
        }
        .frame(height: 36)
    }

    // MARK: - Step 1: Location Choice

    private var locationStepView: some View {
        VStack(spacing: 16) {
            // Elegant Header Icon & Welcome
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)

                    Image(systemName: "cloud.sun.fill")
                        .renderingMode(.original)
                        .font(.system(size: 64))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                }
                .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(String(localized: "Welcome to DeepWeather"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(String(localized: "Search for your city or choose GPS. No automatic location is forced."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                TextField(String(localized: "Search city (e.g. Rome, Milan, London)..."), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .focused($searchFieldFocused)
                    .onChange(of: searchQuery) { _, newValue in
                        handleSearch(newValue)
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            )
            .frame(maxWidth: 460)
            .padding(.horizontal, 24)

            // Results / Options List
            ScrollView {
                VStack(spacing: 8) {
                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text(String(localized: "Searching…"))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.vertical, 16)
                    } else if !searchResults.isEmpty {
                        ForEach(searchResults) { city in
                            Button {
                                selectCity(city)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(city.detail)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.75))
                                    }
                                    Spacer()
                                    if selectedCity?.id == city.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedCity?.id == city.id ? .white.opacity(0.28) : .white.opacity(0.12))
                                )
                            }
                        }
                    } else if !searchQuery.isEmpty {
                        Text(String(localized: "No results."))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.vertical, 12)
                    }

                    // GPS Option Button
                    Button {
                        selectGPS()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Use my current location (GPS)"))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(String(localized: "Requires location permission"))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            if useGPS {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(useGPS ? .white.opacity(0.28) : .white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(useGPS ? .white.opacity(0.5) : .clear, lineWidth: 1)
                        )
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 250)
        }
    }

    // MARK: - Step 2: Preferences

    private var preferencesStepView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text(String(localized: "Preferences"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(String(localized: "Choose your favorite units and notification settings."))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 16) {
                // Units Card
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Units"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))

                    Picker(String(localized: "Units"), selection: $useMetric) {
                        Text(String(localized: "Metric (°C, km/h)")).tag(true)
                        Text(String(localized: "Imperial (°F, mph)")).tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.14))
                )

                // Notifications Card
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Notifications"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))

                    Toggle(isOn: $dailySummary) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Daily summary"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text(String(localized: "Morning weather forecast at 8:00 AM"))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .tint(.white)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.14))
                )
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        Button {
            if currentStep == .preferences {
                finishOnboarding()
            } else {
                nextStep()
            }
        } label: {
            HStack {
                Text(currentStep == .preferences ? String(localized: "Start Exploring") : String(localized: "Next"))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.45))
                if currentStep != .preferences {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .disabled(currentStep == .location && selectedCity == nil && !useGPS)
        .opacity((currentStep == .location && selectedCity == nil && !useGPS) ? 0.5 : 1.0)
        .frame(maxWidth: 400)
    }

    // MARK: - Actions

    private func nextStep() {
        searchFieldFocused = false
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    private func previousStep() {
        searchFieldFocused = false
        if let prev = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = prev
        }
    }

    private func selectCity(_ city: GeoResult) {
        selectedCity = city
        useGPS = false
    }

    private func selectGPS() {
        useGPS = true
        selectedCity = nil
        isRequestingGPS = true
        locationManager.requestWhenInUse()
    }

    private func handleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let results = (try? await geocodingClient.search(trimmed)) ?? []
            guard !Task.isCancelled else { return }
            self.searchResults = results
            self.isSearching = false
        }
    }

    private func finishOnboarding() {
        if dailySummary {
            Task {
                _ = await NotificationManager.requestAuthorization()
            }
        }
        store.completeOnboarding(
            selectedCity: selectedCity,
            useGPS: useGPS,
            useMetric: useMetric,
            dailySummary: dailySummary
        )
    }
}
