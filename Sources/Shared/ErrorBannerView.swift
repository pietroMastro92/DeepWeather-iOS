import SwiftUI

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.orange)
    }
}
