import OSLog
import SwiftData
import SwiftUI

/// "Timer": set up a session, run it, close it out.
struct TimerView: View {
    private static let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "TimerView")

    @Environment(\.uvProvider) private var uvProvider
    @Environment(\.scenePhase) private var scenePhase
    @Environment(LocationService.self) private var locationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.leaderboardService) private var leaderboardService
    @Query private var profiles: [UserProfile]
    @Query private var allSessions: [TanSession]
    @State private var activeStore = ActiveProfileStore()

    @State private var model = TanTimerModel()
    @State private var dashboard = DashboardModel()
    @State private var chosenDuration: TimeInterval?
    @State private var isConfirmingCancel = false

    private var profile: UserProfile? { activeStore.profile(in: profiles) }
    private var skinType: SkinType { profile?.skinType ?? .iii }
    private var spf: Int { profile?.defaultSPF ?? 30 }
    private var report: UVReport? { dashboard.report }

    private var recommendedPlan: TimerPlan? {
        guard let uvIndex = report?.current.uvIndex else { return nil }
        return TimerPlan.recommended(uvIndex: uvIndex, skinType: skinType, spf: spf)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let state = model.state {
                    running(state)
                } else if let completed = model.lastCompleted {
                    SessionSummaryView(session: completed) { model.dismissSummary() }
                } else {
                    setup
                }
            }
            .navigationTitle("Timer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await loadUV() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.applicationDidBecomeActive() }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setup: some View {
        if let plan = recommendedPlan, let report {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    header(for: report)
                    durationPicker(for: plan)
                    planBreakdown(for: effectivePlan(from: plan))
                    MedicalDisclaimer()
                    WeatherAttributionView()
                }
                .padding(Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .accessibilityIdentifier("timer.setup")
            .safeAreaInset(edge: .bottom) {
                Button {
                    model.start(plan: effectivePlan(from: plan), placeName: report.placeName)
                } label: {
                    Label("Start session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(Spacing.l)
                .background(.bar)
            }
        } else {
            ContentUnavailableView {
                Label("This is not the time to sunbathe", systemImage: "moon.stars.fill")
            } description: {
                Text(report == nil
                     ? "Waiting for UV data."
                     : "The UV index is too low to tan. Check again after 10.00.")
            }
        }
    }

    private func effectivePlan(from plan: TimerPlan) -> TimerPlan {
        guard let chosenDuration else { return plan }
        return plan.adjusted(to: .seconds(chosenDuration))
    }

    private func header(for report: UVReport) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(report.placeName)
                .font(.headline)
            Text("UV \(Int(report.current.uvIndex.rounded())) · Skin type \(skinType.numeral) · SPF \(spf.formatted())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func durationPicker(for plan: TimerPlan) -> some View {
        let ceiling = plan.totalDuration.seconds
        let current = chosenDuration ?? ceiling

        return VStack(alignment: .leading, spacing: Spacing.m) {
            LabeledContent {
                Text(SafeExposureCard.format(.seconds(current)))
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
            } label: {
                Text("Session length")
                    .font(.subheadline.weight(.semibold))
            }

            Slider(
                value: Binding(
                    get: { chosenDuration ?? ceiling },
                    set: { chosenDuration = $0 }
                ),
                in: 60...max(ceiling, 120),
                step: 60
            )

            Text("The recommended limit is \(SafeExposureCard.format(.seconds(ceiling))). You can shorten it, but not extend it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private func planBreakdown(for plan: TimerPlan) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            breakdownRow(
                symbol: "arrow.triangle.2.circlepath",
                title: "Flip",
                value: SafeExposureCard.format(plan.flipAt)
            )

            if plan.reapplyPoints.isEmpty {
                Divider()
                breakdownRow(
                    symbol: "drop.fill",
                    title: "Reapply sunscreen",
                    value: String(localized: "not needed")
                )
            } else {
                ForEach(Array(plan.reapplyPoints.enumerated()), id: \.offset) { _, point in
                    Divider()
                    breakdownRow(
                        symbol: "drop.fill",
                        title: "Reapply sunscreen",
                        value: SafeExposureCard.format(point)
                    )
                }
            }
        }
        .cardSurface()
    }

    private func breakdownRow(symbol: String, title: LocalizedStringResource, value: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(title)
            Spacer(minLength: Spacing.s)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Running

    private func running(_ state: TimerState) -> some View {
        // One redraw per second, driven by the system. The state is never mutated here: the
        // ring reads elapsed time from the wall clock, so a suspended app resumes correct.
        TimelineView(.periodic(from: state.startedAt, by: 1)) { context in
            let now = context.date
            let isFinished = state.isFinished(at: now)

            ScrollView {
                VStack(spacing: Spacing.l) {
                    TimerRing(
                        progress: state.progress(at: now),
                        remaining: state.remaining(at: now),
                        isRunning: state.isRunning,
                        tint: Palette.colour(forUVIndex: state.plan.uvIndexAtStart)
                    )
                    .padding(.top, Spacing.l)

                    if state.isAwaitingFlip(at: now) && !isFinished {
                        flipPrompt
                    }

                    if model.notificationsDenied {
                        notificationWarning
                    }

                    if isFinished {
                        finishedPrompt
                    } else {
                        controls(state)
                    }

                    MedicalDisclaimer()
                }
                .padding(Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .animation(.smooth, value: isFinished)
        }
        .alert("Cancel this session?", isPresented: $isConfirmingCancel) {
            Button("Cancel it", role: .destructive) { model.cancel() }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("This session will not be saved.")
        }
    }

    private var flipPrompt: some View {
        VStack(spacing: Spacing.m) {
            Label("Time to turn over", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            Text("You are halfway through the session. Turn over.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("I have turned over") { model.acknowledgeFlip() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private var notificationWarning: some View {
        Label("Notifications are off. Flip and sunscreen reminders will not arrive while the app is closed.", systemImage: "bell.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .cardSurface()
    }

    private var finishedPrompt: some View {
        VStack(spacing: Spacing.m) {
            Text("Your time is up")
                .font(.title3.weight(.semibold))
            Text("Move into the shade and drink plenty of water.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                model.finish(
                    context: modelContext,
                    placeName: report?.placeName ?? locationService.place?.name ?? "",
                    hourly: report?.hourly ?? []
                )
                pushScoreIfSignedIn()
            } label: {
                Label("Save session", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private func controls(_ state: TimerState) -> some View {
        HStack(spacing: Spacing.m) {
            Button {
                state.isRunning ? model.pause() : model.resume()
            } label: {
                Label(
                    state.isRunning ? "Pause" : "Continue",
                    systemImage: state.isRunning ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(role: .destructive) {
                isConfirmingCancel = true
            } label: {
                Label("Finish", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Data

    private func loadUV() async {
        guard let place = locationService.place else { return }
        dashboard.load(from: uvProvider, place: place)
    }

    /// Best-effort sync to the global leaderboard, never surfaced to the user on failure.
    ///
    /// Mirrors the app's "never let a network hiccup interrupt the core flow" posture already
    /// used for the UV cache: the session is already saved locally by the time this runs, so a
    /// dropped connection here costs nothing but a delayed leaderboard update. The push sends
    /// the recomputed running total, not a delta for this one session, matching the server's
    /// overwrite-on-each-push semantics for `BronzlaScores`.
    private func pushScoreIfSignedIn() {
        guard let currentSession = leaderboardService.currentSession() else { return }
        guard let profile else { return }

        // Sign-in now requires a non-empty display name, so this should be unreachable in
        // practice; guarded anyway rather than sending a known-invalid empty string to the
        // server and having the submission silently fail forever.
        let displayName = currentSession.displayName
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.error("Skipping leaderboard score submission: signed-in session has an empty display name.")
            return
        }

        let owned = allSessions.filter { $0.profile?.persistentModelID == profile.persistentModelID }
        let score = BronzScore.make(from: owned)

        Task {
            do {
                try await leaderboardService.submitScore(score, displayName: displayName)
            } catch {
                // Silently swallowed by design; see the doc comment above.
            }
        }
    }
}

/// Post-session summary. Shows what was actually received, not what was planned.
struct SessionSummaryView: View {
    let session: TanSession
    var onDismiss: () -> Void

    private var risk: Double { session.burnRisk }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Image(systemName: risk < 1 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(risk < 1 ? Palette.colour(for: .low) : Palette.colour(for: .veryHigh))
                    .padding(.top, Spacing.xl)

                Text(risk < 1 ? "A safe session" : "You went over the limit")
                    .font(.title2.weight(.semibold))

                VStack(spacing: Spacing.m) {
                    summaryRow("Duration", SafeExposureCard.format(session.duration))
                    Divider()
                    summaryRow("Peak UV", Int(session.peakUVIndex.rounded()).formatted())
                    Divider()
                    summaryRow("Burn threshold", risk.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
                }
                .cardSurface()

                Text("The burn threshold shows what percentage of the dose at which your skin starts to redden you received. 100% is the point at which reddening is expected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    AftercareView(burnRisk: risk)
                } label: {
                    Label("See care advice", systemImage: "leaf.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                ShareCardButton(content: .session(
                    place: session.placeName.isEmpty ? "Bronzla" : session.placeName,
                    duration: session.duration,
                    peakUV: session.peakUVIndex,
                    spf: session.spf,
                    burnRisk: risk
                ))
                .frame(maxWidth: .infinity)

                MedicalDisclaimer()
                WeatherAttributionView()
            }
            .padding(Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            Button("OK", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(Spacing.l)
                .background(.bar)
        }
    }

    private func summaryRow(_ title: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TimerView()
        .environment(LocationService())
        .environment(\.uvProvider, SampleUVProvider(peakUVIndex: 9))
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
