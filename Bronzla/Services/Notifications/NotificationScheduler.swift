import Foundation
import OSLog
import UserNotifications

/// Schedules the session's alerts with the system, up front.
///
/// Everything here is scheduled the moment the timer starts, not fired by a running timer.
/// The whole point of a tanning timer is that the phone goes in a bag: iOS will suspend and
/// may terminate the app, and a notification driven by app code would simply never arrive.
/// Pausing cancels and re-scheduling replaces, so the pending set always matches the state.
struct NotificationScheduler: Sendable {

    private enum Identifier {
        static let flip = "bronzla.session.flip"
        static let end = "bronzla.session.end"
        static let reapplyPrefix = "bronzla.session.reapply."
        static var all: [String] { [flip, end] }
    }

    /// Computed rather than stored: `UNUserNotificationCenter` is not `Sendable`, so holding
    /// one would force this scheduler to give up its own `Sendable` conformance. The singleton
    /// is itself thread-safe, so fetching it per call costs nothing.
    private var center: UNUserNotificationCenter { .current() }
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "Notifications")

    /// Asks for permission. Called at the moment the user starts their first session, when
    /// the reason is self-evident, rather than on launch when it reads as a demand.
    @discardableResult
    func requestAuthorisation() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification authorisation failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    var isAuthorised: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
    }

    /// Replaces all pending session alerts with the ones this state implies.
    func reschedule(for state: TimerState, now: Date = .now) async {
        await cancelAll()
        guard let alerts = state.pendingAlertDates(at: now) else { return }

        if let flip = alerts.flip {
            await schedule(
                id: Identifier.flip,
                at: flip,
                title: String(localized: "Time to turn over"),
                body: String(localized: "Turn over. You are halfway through the session."),
                now: now
            )
        }

        for (offset, date) in alerts.reapply.enumerated() {
            await schedule(
                id: Identifier.reapplyPrefix + String(offset),
                at: date,
                title: String(localized: "Reapply your sunscreen"),
                body: String(localized: "Two hours are up. Reapply your sunscreen, especially if you have been in the sea."),
                now: now
            )
        }

        await schedule(
            id: Identifier.end,
            at: alerts.end,
            title: String(localized: "Session complete"),
            body: String(localized: "Your safe time is up. Move into the shade and drink plenty of water."),
            now: now
        )
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            Identifier.all.contains($0) || $0.hasPrefix(Identifier.reapplyPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    private func schedule(id: String, at date: Date, title: String, body: String, now: Date) async {
        let delay = date.timeIntervalSince(now)
        // UNTimeIntervalNotificationTrigger rejects non-positive intervals outright.
        guard delay > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Could not schedule \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
