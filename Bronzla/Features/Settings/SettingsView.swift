import SwiftData
import SwiftUI

/// Profile, protection defaults and the legal surface.
///
/// No pricing anywhere: the app is bought once and mentioning money afterwards makes a paid
/// app feel like a free one that is about to ask.
struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \TanSession.startedAt, order: .reverse) private var sessions: [TanSession]
    @Environment(\.modelContext) private var modelContext
    @State private var activeStore = ActiveProfileStore()

    @State private var isShowingQuiz = false
    @State private var isConfirmingReset = false
    @State private var exportURL: URL?
    @State private var dailyAlertScheduler = DailyUVAlertScheduler()
    @State private var dailyAlertsEnabled = false
    @State private var healthEnabled = HealthStore.shared.isEnabled

    /// The profile everything here edits. Reads through `ActiveProfileStore` rather than
    /// `profiles.first` so this screen stays correct once a family has more than one profile.
    private var profile: UserProfile? { activeStore.profile(in: profiles) }

    var body: some View {
        NavigationStack {
            Form {
                profilesSection
                skinSection
                alertsSection
                healthSection
                aboutSection
                dataSection
            }
            .navigationTitle("Settings")
            // Idempotent, so this is a no-op after the first run, or once a second profile
            // exists; see `ActiveProfileResolution.migrateLegacyProfileIfNeeded`.
            .task { ActiveProfileResolution.migrateLegacyProfileIfNeeded(profiles) }
            .sheet(isPresented: $isShowingQuiz) {
                SkinTypeQuizView { skinType in
                    apply(skinType)
                }
            }
            .alert("Delete all data?", isPresented: $isConfirmingReset) {
                Button("Delete", role: .destructive) { resetEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your sessions, photos and skin type will be permanently deleted. This cannot be undone.")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var profilesSection: some View {
        Section {
            NavigationLink {
                ProfileListView()
            } label: {
                HStack(spacing: Spacing.m) {
                    if let profile {
                        Circle()
                            .fill(profile.accentColour)
                            .frame(width: 12, height: 12)
                    }
                    Text(profile?.name.isEmpty == false ? profile!.name : String(localized: "Me"))
                    Spacer(minLength: 0)
                    Text(profiles.count > 1 ? "\(profiles.count) profil" : "")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("settings.profiles")
        } header: {
            Text("Profiles")
        } footer: {
            Text("Create a separate profile for each family member on the trip; every profile has its own skin type and safe time.")
        }
    }

    @ViewBuilder
    private var skinSection: some View {
        Section {
            if let profile {
                LabeledContent {
                    Text("Type \(profile.skinType.numeral)")
                        .foregroundStyle(.secondary)
                } label: {
                    Text(profile.skinType.title)
                }

                Text(profile.skinType.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Take the skin type test") { isShowingQuiz = true }
        } header: {
            Text("Skin type")
        } footer: {
            Text("Your skin type is the basis of your safe sun time. If it is wrong, the times are wrong too.")
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("High UV alert", isOn: $dailyAlertsEnabled)
        } header: {
            Text("Notifications")
        } footer: {
            Text("If the UV index will reach 8 or above the next day, we tell you in the morning.")
        }
        .task { dailyAlertsEnabled = dailyAlertScheduler.isEnabled }
        .onChange(of: dailyAlertsEnabled) { _, isOn in
            dailyAlertScheduler.isEnabled = isOn
            Task { if isOn { await dailyAlertScheduler.requestAuthorisation() } }
        }
    }

    private var healthSection: some View {
        Section {
            Toggle("Save to Health", isOn: $healthEnabled)
        } header: {
            Text("Health")
        } footer: {
            Text("Your sessions are written to the Health app as time spent in the sun. We do not read your data.")
        }
        .onChange(of: healthEnabled) { _, isOn in
            HealthStore.shared.isEnabled = isOn
            Task { if isOn { await HealthStore.shared.requestAuthorisation() } }
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink("Medical disclaimer") { DisclaimerDetailView() }
            NavigationLink("Privacy") { PrivacyDetailView() }
        } header: {
            Text("About")
        } footer: {
            Text("Bronzla \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Section {
            if sessions.isEmpty {
                LabeledContent("Export") {
                    Text("no records")
                        .foregroundStyle(.secondary)
                }
            } else if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Export sessions (CSV)", systemImage: "square.and.arrow.up")
                }
            }

            Button("Delete all data", role: .destructive) { isConfirmingReset = true }
        } header: {
            Text("Data")
        } footer: {
            Text("The exported file stays on your device. Where it goes is your decision.")
        }
        // Regenerated whenever the session set changes, so the shared file is never stale.
        .task(id: sessions.count) { exportURL = SessionExporter.writeCSV(for: sessions) }
    }

    // MARK: - Actions

    private func apply(_ skinType: SkinType) {
        guard let profile else {
            let created = UserProfile(skinType: skinType, hasCompletedOnboarding: true)
            modelContext.insert(created)
            return
        }
        profile.skinType = skinType
        profile.defaultSPF = skinType.recommendedSPF
        profile.hasCompletedOnboarding = true
    }

    private func resetEverything() {
        try? modelContext.delete(model: TanSession.self)
        try? modelContext.delete(model: UserProfile.self)
        Task { await UVReportCache.shared.removeAll() }
    }
}

/// The full disclaimer, reachable from Settings and linked from anywhere the short form
/// appears. Kept as one canonical text so the wording never drifts between screens.
struct DisclaimerDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Bronzla is not a medical device and does not give medical advice.")
                    .font(.headline)

                Text("""
                The times in this app are average values based on the Fitzpatrick skin type scale \
                and the World Health Organization's definition of the UV index. Real skin response \
                varies with medication, skin conditions, pregnancy, altitude, reflection from water \
                and sand, cloud cover, and how well sunscreen has been applied.

                Treat these times as a rough guide, not an upper limit. If your skin starts to \
                redden, move into the shade even if the time is not up.

                See a dermatologist if you have moles, notice a change in them, have a family \
                history of skin cancer, or react unusually to the sun. This app is never a \
                substitute for an examination.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(Spacing.l)
        }
        .navigationTitle("Medical disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("Your data stays on your device.")
                    .font(.headline)

                Text("""
                Bronzla does not ask you to create an account, does not track you and uses no \
                third party analytics. Your sessions, photos and skin type are stored only on \
                your device.

                Your location is used to fetch weather data and is sent to Apple Weather. In the \
                cache it is rounded to roughly one kilometre rather than kept as an exact \
                coordinate.

                You can permanently delete all of your data with a single tap in Settings.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(Spacing.l)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
