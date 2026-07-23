import SwiftData
import SwiftUI

@main
struct BronzlaApp: App {
    @State private var locationService = LocationService()
    @State private var uvProvider: any UVDataProviding = WeatherKitUVProvider()

    private let container: ModelContainer = {
        do {
            #if DEBUG
            // UI tests need a clean slate per launch. Guarded to DEBUG so no shipping build
            // can be talked into discarding a user's history by a launch argument.
            if ProcessInfo.processInfo.arguments.contains("-uiTestingFreshState") {
                UserDefaults.standard.removePersistentDomain(
                    forName: Bundle.main.bundleIdentifier ?? "com.hmdcorp.bronzla"
                )
                return try ModelContainer(
                    for: UserProfile.self, TanSession.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
            #endif
            return try ModelContainer(for: UserProfile.self, TanSession.self)
        } catch {
            // A store that will not open is not recoverable at runtime, and silently falling
            // back to an in-memory container would quietly discard the user's history.
            fatalError("SwiftData store could not be opened: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(locationService)
                .environment(\.uvProvider, uvProvider)
        }
        .modelContainer(container)
    }
}

/// Injected rather than referenced directly so previews can substitute `SampleUVProvider`
/// without WeatherKit entitlements, which previews never have.
private struct UVProviderKey: EnvironmentKey {
    static let defaultValue: any UVDataProviding = SampleUVProvider()
}

extension EnvironmentValues {
    var uvProvider: any UVDataProviding {
        get { self[UVProviderKey.self] }
        set { self[UVProviderKey.self] = newValue }
    }
}
