import SwiftData
import SwiftUI

/// Tab shell. Five tabs is the ceiling before the bar starts feeling like a menu; the sixth
/// and seventh features live inside these rather than beside them.
struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingOnboarding = false
    @State private var selectedTab = 0
    @State private var deepLink = DeepLink.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max.fill", value: 0) {
                DashboardView()
            }
            Tab("Forecast", systemImage: "chart.xyaxis.line", value: 1) {
                ForecastView()
            }
            Tab("Timer", systemImage: "timer", value: 2) {
                TimerView()
            }
            Tab("Tracker", systemImage: "calendar", value: 3) {
                TrackerView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                SettingsView()
            }
        }
        .task { ensureProfileExists() }
        // Full screen rather than a sheet: the quiz is not optional. Every exposure time in
        // the app is wrong until it has been answered, so it must not be swipeable away.
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            SkinTypeQuizView { skinType in
                apply(skinType)
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: needsOnboarding, initial: true) { _, needsOnboarding in
            isShowingOnboarding = needsOnboarding
        }
        .onChange(of: deepLink.pending) { _, destination in
            guard destination == .timer else { return }
            selectedTab = 2
            // Cleared immediately so a later relaunch does not re-navigate.
            deepLink.pending = nil
        }
    }

    private var needsOnboarding: Bool {
        guard let profile = profiles.first else { return false }
        return !profile.hasCompletedOnboarding
    }

    /// Creates the single local profile on first launch. Runs on every appearance because it
    /// is idempotent and cheaper than tracking a separate "did seed" flag that could drift.
    private func ensureProfileExists() {
        guard profiles.isEmpty else {
            // Names and activates a profile created before multi-profile support. Idempotent,
            // so it no-ops on every launch after the first and once a second profile exists.
            ActiveProfileResolution.migrateLegacyProfileIfNeeded(profiles)
            return
        }
        modelContext.insert(UserProfile(name: String(localized: "Me"), isActive: true))
    }

    private func apply(_ skinType: SkinType) {
        guard let profile = profiles.first else { return }
        profile.skinType = skinType
        profile.defaultSPF = skinType.recommendedSPF
        profile.hasCompletedOnboarding = true
    }
}

/// Temporary stand-in for tabs not yet built. Kept deliberately plain so it never gets
/// mistaken for a finished screen.
struct PlaceholderView: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: "hammer.fill")
            } description: {
                Text(detail)
            }
            .navigationTitle(Text(title))
        }
    }
}

#Preview {
    RootView()
        .environment(LocationService())
        .environment(\.uvProvider, SampleUVProvider())
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
