import SwiftUI

struct ForecastListView: View {
    let items: [WeatherStore.DayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { day in
                ForecastRowView(day: day)
            }
        }
    }
}

private struct ForecastRowView: View {
    let day: WeatherStore.DayItem

    var body: some View {
        HStack(spacing: 10) {
            Text(day.title)
                .font(.callout)
                .frame(width: 52, alignment: .leading)

            Image(systemName: day.symbol)
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            if day.precipChance > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                    Text("\(day.precipChance)%")
                }
                .font(.caption2)
                .foregroundStyle(.blue)
                .frame(width: 48, alignment: .leading)
            } else {
                Text(" ")
                    .font(.caption2)
                    .frame(width: 48, alignment: .leading)
            }

            Spacer()

            Text(day.minText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(day.maxText)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}
