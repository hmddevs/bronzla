import SwiftUI
import WeatherKit

/// Apple requires the Weather trademark and a link to the data sources anywhere WeatherKit
/// data is displayed. Omitting it is an App Review rejection, so it lives in a reusable view
/// that every data-bearing screen embeds.
struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let attribution {
                AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(height: 14)

                Link(destination: attribution.legalPageURL) {
                    Text("Data sources")
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .task {
            // Cheap and cached by the framework, but it can fail without entitlements, in
            // which case showing nothing is correct: there is no WeatherKit data on screen.
            attribution = try? await WeatherService.shared.attribution
        }
    }
}
