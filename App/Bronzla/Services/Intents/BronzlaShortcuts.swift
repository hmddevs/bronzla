import AppIntents
import Foundation

/// Siri and Shortcuts entry points.
///
/// Two intents only. A tanning app does not need a scriptable API surface; it needs the two
/// things someone actually says while holding a towel. Both read the shared snapshot rather
/// than fetching, so they answer instantly and cannot hang on a slow network.
struct CurrentUVIntent: AppIntent {
    static let title: LocalizedStringResource = "Check the UV index"
    static let description = IntentDescription("Tells you the latest UV index for your location.")
    /// Answers in place. Opening the app to read one number would be a worse experience than
    /// not asking Siri at all.
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = SharedUVSnapshot.read(), !snapshot.isExpired else {
            return .result(dialog: "No UV data yet. Open Bronzla and set your location.")
        }

        let index = Int(snapshot.uvIndex.rounded())
        let category = snapshot.category.localisedTitle

        guard let seconds = snapshot.recommendedSeconds else {
            return .result(dialog: "For \(snapshot.placeName), the UV index is \(index), \(category). There is no burn risk right now.")
        }

        let minutes = Int((seconds / 60).rounded())
        return .result(
            dialog: "For \(snapshot.placeName), the UV index is \(index), \(category). Based on your skin type, your safe time is about \(minutes) minutes."
        )
    }
}

/// Opens the timer tab rather than starting a session outright.
///
/// Starting one silently would commit the user to a duration they never saw, computed from a
/// reading they never checked. On a safety feature, the confirmation is the point.
struct StartTanningIntent: AppIntent {
    static let title: LocalizedStringResource = "Start sunbathing"
    static let description = IntentDescription("Opens the timer in Bronzla.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.shared.pending = .timer
        return .result()
    }
}

struct BronzlaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentUVIntent(),
            phrases: [
                "\(.applicationName) UV indeksi",
                "Check UV with \(.applicationName)",
                "UV indeksi nedir \(.applicationName)",
            ],
            shortTitle: "UV index",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: StartTanningIntent(),
            phrases: [
                "Start tanning with \(.applicationName)",
                "Open \(.applicationName) timer",
            ],
            shortTitle: "Start sunbathing",
            systemImageName: "timer"
        )
    }
}

/// Carries an intent's destination to the view layer.
///
/// A singleton because `AppIntent.perform()` has no access to the SwiftUI environment, and the
/// alternative (a notification centre post) is harder to follow for exactly one signal.
@MainActor
@Observable
final class DeepLink {
    enum Destination { case timer }

    static let shared = DeepLink()

    /// Consumed and cleared by `RootView`, so a relaunch does not re-navigate.
    var pending: Destination?

    private init() {}
}
