import SwiftData
import SwiftUI

@main
struct BronzlaApp: App {
    @State private var locationService: LocationService = {
        let service = LocationService()
        #if DEBUG
        // Screenshot runs need a place immediately, since there is no route to a real
        // CoreLocation fix in the simulator. Guarded to DEBUG so no shipping build can be
        // talked into pinning location by a launch argument.
        ScreenshotSeed.applyIfActive(to: service)
        #endif
        return service
    }()
    @State private var uvProvider: any UVDataProviding = {
        #if DEBUG
        // Guarded to DEBUG so no shipping build can be talked into serving fabricated UV
        // readings by a launch argument.
        if ScreenshotSeed.isActive { return ScreenshotUVProvider() }
        #endif
        return WeatherKitUVProvider()
    }()
    @State private var leaderboardService: any LeaderboardServiceProviding = LiveLeaderboardService()

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
            // Screenshot captures need believable, deterministic content rather than an empty
            // first-run state. Guarded to DEBUG so no shipping build can be talked into
            // fabricating history by a launch argument.
            if ScreenshotSeed.isActive {
                return try ScreenshotSeed.makeContainer()
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
                .environment(\.leaderboardService, leaderboardService)
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

/// Injected rather than referenced directly so previews and tests can substitute
/// `SampleLeaderboardProvider` without a real backend, which neither ever has.
private struct LeaderboardServiceKey: EnvironmentKey {
    static let defaultValue: any LeaderboardServiceProviding = SampleLeaderboardProvider()
}

extension EnvironmentValues {
    var leaderboardService: any LeaderboardServiceProviding {
        get { self[LeaderboardServiceKey.self] }
        set { self[LeaderboardServiceKey.self] = newValue }
    }
}
