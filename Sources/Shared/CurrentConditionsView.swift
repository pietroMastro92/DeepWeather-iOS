import SwiftUI

struct CurrentConditionsView: View {
    let locationName: String
    let locationDetail: String
    let tempText: String
    let conditionText: String
    let iconName: String
    let iconKind: WeatherAnimationKind
    let locations: [SavedLocation]
    let selectedLocationID: String?
    let onSelectLocation: (String?) -> Void
    var onGradient: Bool = false

    private var primaryText: Color { onGradient ? .white : .primary }
    private var secondaryText: Color { onGradient ? .white.opacity(0.85) : .secondary }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                LocationSwitcherMenu(
                    locationName: locationName,
                    locations: locations,
                    selectedLocationID: selectedLocationID,
                    onSelect: onSelectLocation,
                    textColor: primaryText,
                    chevronColor: secondaryText
                )
                Text(locationDetail)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(tempText)
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .foregroundStyle(primaryText)
                    .contentTransition(.numericText())
                    .animation(.default, value: tempText)

                Text(conditionText)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            AnimatedWeatherIconView(
                symbol: iconName,
                kind: iconKind,
                accessibilityLabel: conditionText,
                foregroundColor: primaryText
            )
            .padding(.top, 2)
        }
        .frame(minHeight: 96)
    }
}

private struct LocationSwitcherMenu: View {
    let locationName: String
    let locations: [SavedLocation]
    let selectedLocationID: String?
    let onSelect: (String?) -> Void
    let textColor: Color
    let chevronColor: Color

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                Label("Automatic (IP)", systemImage: selectedLocationID == nil ? "checkmark" : "location")
            }

            if !locations.isEmpty {
                Divider()
                ForEach(locations) { location in
                    Button {
                        onSelect(location.id)
                    } label: {
                        Label(location.name, systemImage: selectedLocationID == location.id ? "checkmark" : "mappin")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(locationName)
                    .font(.headline)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(chevronColor)
            }
        }
    }
}
