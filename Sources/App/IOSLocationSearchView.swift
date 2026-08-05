import SwiftUI

struct IOSLocationSearchView: View {
    @Bindable var store: WeatherStore

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [GeoResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let client = GeocodingClient()

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "Searching…"))
                            .foregroundStyle(.secondary)
                    }
                } else if !results.isEmpty {
                    ForEach(results) { result in
                        Button {
                            select(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.name)
                                Text(result.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else if !query.isEmpty {
                    Text(String(localized: "No results."))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "Add location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: "Search city…")
            )
            .autocorrectionDisabled()
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func scheduleSearch(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [client] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = (try? await client.search(trimmed)) ?? []
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    private func select(_ result: GeoResult) {
        store.selectLocation(result)
        dismiss()
    }
}
