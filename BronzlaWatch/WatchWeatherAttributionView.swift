import SwiftUI
import WeatherKit

/// Apple requires the Weather trademark and a data-source link anywhere WeatherKit data is
/// shown. The phone app has its own `WeatherAttributionView`; this is a watch-sized twin
/// rather than a shared file, because the phone version depends on `Spacing`, a design-token
/// type that has no reason to exist on a screen this small.
struct WatchWeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        Group {
            if let attribution {
                Link(destination: attribution.legalPageURL) {
                    Text("Data sources")
                        .font(.system(size: 10))
                }
            }
        }
        .foregroundStyle(.tertiary)
        .task {
            attribution = try? await WeatherService.shared.attribution
        }
    }
}
