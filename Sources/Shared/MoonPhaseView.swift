import SwiftUI

struct MoonPhaseView: View {
    let items: [WeatherStore.MoonItem]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: item.phaseSymbol)
                            .font(.system(size: 16))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.phaseName)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(item.illuminationText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
