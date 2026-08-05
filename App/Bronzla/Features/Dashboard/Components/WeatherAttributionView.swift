import SwiftUI
import WeatherKit

/// Apple requires the Weather trademark and a link to the data sources anywhere WeatherKit
/// data is displayed. Omitting it is an App Review rejection, so it lives in a reusable view
/// that every data-bearing screen embeds.
struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        // A hairline and real vertical space separate this from the disclaimer above it.
        // Without them the required attribution read as the last line of a grey paragraph
        // rather than a distinct credit, which is both worse typography and a weaker
        // acknowledgement than Apple asks for.
        VStack(spacing: Spacing.m) {
            if let attribution {
                Divider()
                    .frame(maxWidth: 120)

                HStack(spacing: Spacing.s) {
                    AsyncImage(url: colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(height: 16)

                    Link(destination: attribution.legalPageURL) {
                        Text("Data sources")
                            .font(.caption2)
                            .underline()
                    }
                }
            }
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.l)
        .task {
            // Cheap and cached by the framework, but it can fail without entitlements, in
            // which case showing nothing is correct: there is no WeatherKit data on screen.
            attribution = try? await WeatherService.shared.attribution
        }
    }
}
