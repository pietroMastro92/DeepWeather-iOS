import SwiftUI

struct DetailGridView: View {
    let items: [WeatherStore.DetailItem]

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.symbol)
                        .frame(width: 18)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
