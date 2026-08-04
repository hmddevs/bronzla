import SwiftData
import SwiftUI
import WidgetKit

/// "Today": the current reading, what it means for this user's skin, and nothing else.
struct DashboardView: View {
    @Environment(\.uvProvider) private var uvProvider
    @Environment(LocationService.self) private var locationService
    @Query private var profiles: [UserProfile]
    @State private var activeStore = ActiveProfileStore()

    @State private var model = DashboardModel()
    @State private var isChoosingPlace = false

    private var profile: UserProfile? { activeStore.profile(in: profiles) }
    private var skinType: SkinType { profile?.skinType ?? .iii }
    private var spf: Int { profile?.defaultSPF ?? 30 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    switch model.phase {
                    case .idle, .loading:
                        loadingState
                    case .loaded(let report):
                        content(for: report)
                    case .failed(let message, let detail):
                        failureState(message, detail: detail)
                    }
                }
                // Without this the VStack shrinks to its widest child. In the loading state
                // that is UVGauge at maxWidth 280, so the ScrollView became 312pt wide on a
                // 390pt screen and `.background` painted only that, leaving black bars down
                // both sides. The loaded and failed states happened to fill, which is why it
                // only showed while loading.
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .background(background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isChoosingPlace = true
                    } label: {
                        Label("Choose a location", systemImage: "mappin.and.ellipse")
                    }
                }
            }
            .sheet(isPresented: $isChoosingPlace) {
                PlacePickerView()
            }
            .refreshable { await refresh(isManual: true) }
            // Published for the widget extension, which cannot see the app's own container.
            // Driven from here rather than from DashboardModel because the recommended time
            // depends on the profile, which the model deliberately knows nothing about.
            .onChange(of: model.report, initial: true) { _, report in
                publishToWidget(report)
                if let report {
                    Task { await DailyUVAlertScheduler().reschedule(using: report) }
                }
            }
            .task(id: locationService.place) { await refresh() }
            .task { locationService.requestLocation() }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var loadingState: some View {
        UVGauge(uvIndex: 0, isLoading: true)
            .padding(.top, Spacing.xl)

        if case .denied = locationService.status {
            permissionDeniedNotice
        } else {
            ProgressView("Fetching location and UV data…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func content(for report: UVReport) -> some View {
        header(for: report)

        UVGauge(uvIndex: report.current.uvIndex)
            .accessibilityIdentifier("dashboard.uvGauge")

        conditions(for: report)

        SafeExposureCard(uvIndex: report.current.uvIndex, skinType: skinType, spf: spf)
            .accessibilityIdentifier("dashboard.safeExposureCard")

        adviceCard(for: report)

        if report.source == .sample {
            Label("Showing sample data. This is not a real UV measurement.", systemImage: "flask.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if report.source == .cached || report.isStale {
            stalenessNotice(for: report)
        }

        MedicalDisclaimer()

        WeatherAttributionView()
            .padding(.top, Spacing.s)
    }

    @ViewBuilder
    private func failureState(_ message: String, detail: String? = nil) -> some View {
        ContentUnavailableView {
            Label("Could not fetch data", systemImage: "cloud.slash")
        } description: {
            Text(message)
            // The underlying error, shown because a beta tester without a cable cannot reach
            // Console.app to read the log. It stays on the device: it is displayed and copied
            // locally, never logged publicly, because framework errors can embed the request
            // URL and that carries the coordinates.
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .padding(.top, Spacing.s)
            }
        } actions: {
            Button("Try again") {
                Task { await refresh(isManual: true) }
            }
            .buttonStyle(.borderedProminent)

            Button("Choose a location") { isChoosingPlace = true }
        }
        .padding(.top, Spacing.xxl)
    }

    private var permissionDeniedNotice: some View {
        VStack(spacing: Spacing.m) {
            Text("Location permission was not granted. You can carry on by choosing a city.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose a city") { isChoosingPlace = true }
                .buttonStyle(.borderedProminent)
        }
        .cardSurface()
    }

    // MARK: - Sections

    private func header(for report: UVReport) -> some View {
        VStack(spacing: Spacing.xs) {
            Label(report.placeName, systemImage: "location.fill")
                .font(.headline)

            Text(report.current.observedAt, format: .dateTime.hour().minute())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.s)
    }

    private func conditions(for report: UVReport) -> some View {
        HStack(spacing: Spacing.xl) {
            metric(
                symbol: report.current.conditionSymbol,
                value: report.current.temperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))),
                label: "Temperature"
            )

            if let sunset = report.current.sunset {
                metric(
                    symbol: "sunset.fill",
                    value: sunset.formatted(.dateTime.hour().minute()),
                    label: "Sunset"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    private func metric(symbol: String, value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func adviceCard(for report: UVReport) -> some View {
        let category = report.current.category
        return HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: category.requiresProtection ? "sun.max.trianglebadge.exclamationmark.fill" : "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(Palette.colour(for: category))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(category.title)
                    .font(.headline)
                Text(category.advice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("UV index bands: World Health Organization")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .cardSurface()
    }

    private func stalenessNotice(for report: UVReport) -> some View {
        Label {
            Text("Offline data · \(report.fetchedAt, format: .relative(presentation: .named))")
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var background: some View {
        Palette.backgroundWash(forUVIndex: model.report?.current.uvIndex ?? 0)
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.8), value: model.report?.current.uvIndex)
    }

    // MARK: - Actions

    private func publishToWidget(_ report: UVReport?) {
        guard let report else { return }
        SharedUVSnapshot.write(
            SharedUVSnapshot(
                uvIndex: report.current.uvIndex,
                placeName: report.placeName,
                temperatureCelsius: report.current.temperature.converted(to: .celsius).value,
                recommendedSeconds: ExposureCalculator.recommendedSession(
                    uvIndex: report.current.uvIndex,
                    skinType: skinType,
                    spf: spf
                )?.seconds,
                skinTypeNumeral: skinType.numeral,
                fetchedAt: report.fetchedAt
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refresh(isManual: Bool = false) async {
        guard let place = locationService.place else { return }
        model.load(from: uvProvider, place: place, isManualRefresh: isManual)
    }
}

/// Shown on every screen that gives exposure guidance. Non-negotiable: the numbers this app
/// produces are population averages applied to a person it has never examined.
#Preview("High UV") {
    DashboardView()
        .environment(LocationService())
        .environment(\.uvProvider, SampleUVProvider(peakUVIndex: 10))
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
