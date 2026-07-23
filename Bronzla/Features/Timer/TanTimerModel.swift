import Foundation
import Observation
import OSLog
import SwiftData

/// Owns the running session: state transitions, persistence across app termination,
/// notification scheduling and logging the finished session.
///
/// The state itself lives in a pure `TimerState`; this type is the impure shell around it.
@MainActor
@Observable
final class TanTimerModel {

    private(set) var state: TimerState?
    private(set) var notificationsDenied = false
    /// Set once a session has been written to the store, so the summary can be shown.
    private(set) var lastCompleted: TanSession?

    private let scheduler = NotificationScheduler()
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "TanTimer")
    private let defaults: UserDefaults
    private static let storageKey = "bronzla.timer.state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    var isActive: Bool { state != nil }

    // MARK: - Lifecycle

    func start(plan: TimerPlan, placeName: String = "", now: Date = .now) {
        var state = TimerState(plan: plan, startedAt: now)
        state.resume(at: now)
        self.state = state
        lastCompleted = nil
        persist()
        LiveActivityController.start(state: state, placeName: placeName, now: now)

        Task {
            let granted = await scheduler.isAuthorised ? true : await scheduler.requestAuthorisation()
            notificationsDenied = !granted
            guard granted, let current = self.state else { return }
            await scheduler.reschedule(for: current)
        }
    }

    func pause(now: Date = .now) {
        guard var state, state.isRunning else { return }
        state.pause(at: now)
        self.state = state
        persist()
        LiveActivityController.update(state: state, now: now)
        Task { await scheduler.cancelAll() }
    }

    func resume(now: Date = .now) {
        guard var state, !state.isRunning else { return }
        state.resume(at: now)
        self.state = state
        persist()
        LiveActivityController.update(state: state, now: now)
        Task { [state] in await scheduler.reschedule(for: state) }
    }

    func acknowledgeFlip() {
        guard var state else { return }
        state.acknowledgeFlip()
        self.state = state
        persist()
        LiveActivityController.update(state: state)
        Task { [state] in
            guard state.isRunning else { return }
            await scheduler.reschedule(for: state)
        }
    }

    /// Ends the session and writes it to the store.
    ///
    /// - Parameter hourly: The UV profile covering the session, used to integrate the dose
    ///   actually received. Falls back to the UV at start when no profile is available, which
    ///   is the conservative direction only around solar noon, so the shortfall is noted.
    func finish(
        context: ModelContext,
        placeName: String,
        hourly: [HourlyUV],
        now: Date = .now
    ) {
        guard let state else { return }

        let elapsed = Duration.seconds(state.elapsed(at: now))
        let dose: Double
        let peakUV: Double

        let samplesInWindow = hourly.filter { $0.date >= state.startedAt.addingTimeInterval(-3600) && $0.date <= now }
        if samplesInWindow.isEmpty {
            dose = ExposureCalculator.dose(uvIndex: state.plan.uvIndexAtStart, over: elapsed, spf: state.plan.spf)
            peakUV = state.plan.uvIndexAtStart
        } else {
            dose = ExposureCalculator.dose(across: samplesInWindow, from: state.startedAt, to: now, spf: state.plan.spf)
            peakUV = samplesInWindow.map(\.uvIndex).max() ?? state.plan.uvIndexAtStart
        }

        let session = TanSession(
            startedAt: state.startedAt,
            endedAt: now,
            placeName: placeName,
            spf: state.plan.spf,
            skinType: state.plan.skinType,
            erythemalDose: dose,
            peakUVIndex: peakUV
        )
        context.insert(session)

        do {
            try context.save()
        } catch {
            // Losing a session silently would erode trust in the whole tracker, so this is
            // logged loudly. The session object stays in memory for the summary regardless.
            logger.error("Could not save session: \(error.localizedDescription, privacy: .public)")
        }

        lastCompleted = session
        Task { await HealthStore.shared.save(session: session) }
        cancel()
    }

    /// Abandons the session without recording it.
    func cancel() {
        state = nil
        defaults.removeObject(forKey: Self.storageKey)
        LiveActivityController.end()
        Task { await scheduler.cancelAll() }
    }

    /// Re-syncs notifications after the app returns from the background, where the pending
    /// set may have been consumed while suspended.
    func applicationDidBecomeActive() {
        guard let state, state.isRunning else { return }
        LiveActivityController.update(state: state)
        Task { await scheduler.reschedule(for: state) }
    }

    // MARK: - Persistence

    /// Stored in `UserDefaults` rather than SwiftData: it is a single small value read on
    /// launch, and a running timer must survive termination without a store fetch.
    private func persist() {
        guard let state else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        do {
            defaults.set(try JSONEncoder.bronzla.encode(state), forKey: Self.storageKey)
        } catch {
            logger.error("Could not persist timer: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let restored = try? JSONDecoder.bronzla.decode(TimerState.self, from: data)
        else { return }

        // A session left running for far longer than it should have is stale, not resumable:
        // the phone was probably off, and resuming would show a wildly wrong elapsed time.
        let age = Date.now.timeIntervalSince(restored.startedAt)
        guard age < 12 * 3600 else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }

        state = restored
    }
}
