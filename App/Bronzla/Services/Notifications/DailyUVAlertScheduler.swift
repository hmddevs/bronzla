import Foundation
import OSLog
import UserNotifications

/// Schedules a morning heads-up for any upcoming day whose forecast peak UV reaches the
/// "very high" band, so a user can plan around it before they have already left the house.
///
/// Kept entirely separate from `NotificationScheduler`: that one owns the in-session flip and
/// reapply alerts, fires within minutes and is cancelled the moment a session ends. This one
/// looks days ahead and must never be touched by a session's cancel-and-reschedule cycle, hence
/// its own identifier prefix.
struct DailyUVAlertScheduler: Sendable {

    private enum Identifier {
        static let prefix = "bronzla.dailyuv.alert."
    }

    /// The WHO "very high" floor. Kept in step with `UVCategory` rather than a second magic
    /// number, so a change to the WHO bands cannot silently desynchronise the two.
    static let alertThreshold = UVCategory.veryHigh

    /// iOS will happily schedule further out, but a forecast more than a week away is not
    /// trustworthy enough to wake someone up over.
    static let maxLookaheadDays = 7

    private static let enabledKey = "bronzla.dailyUVAlerts.enabled"

    /// Computed rather than stored, for the same reason as `NotificationScheduler`:
    /// `UNUserNotificationCenter` is not `Sendable`, and a stored property would strip this
    /// struct of its own `Sendable` conformance.
    private var center: UNUserNotificationCenter { .current() }
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "DailyUVAlerts")
    // UserDefaults is thread-safe internally but predates Sendable annotation; the same
    // reasoning `NotificationScheduler` applies to `UNUserNotificationCenter` applies here.
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Opt-in, default off: a stranger asking to wake someone up with push notifications about
    /// the weather needs explicit consent, not an assumption.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    @discardableResult
    func requestAuthorisation() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification authorisation failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Pure day-selection logic, isolated from the notification centre so it can be tested
    /// without a simulator. Only strictly future days within the lookahead window qualify;
    /// today is excluded since a morning alert for a day already under way is pointless.
    static func qualifyingDays(
        in daily: [DailyUV],
        from now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyUV] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: maxLookaheadDays, to: startOfToday) else {
            return []
        }

        return daily
            .filter { day in
                let dayStart = calendar.startOfDay(for: day.date)
                return dayStart > startOfToday
                    && dayStart <= cutoff
                    && day.category >= alertThreshold
            }
            .sorted { $0.date < $1.date }
    }

    /// Replaces every pending daily-UV alert with the ones today's report implies. Safe to call
    /// on every fresh report fetch: cancelling first means a UV forecast that has cooled off
    /// since the last fetch cannot leave a stale alert behind.
    func reschedule(using report: UVReport, now: Date = .now, calendar: Calendar = .current) async {
        await cancelAll()
        guard isEnabled else { return }

        let days = Self.qualifyingDays(in: report.daily, from: now, calendar: calendar)
        for (offset, day) in days.enumerated() {
            guard let fireDate = morningAlertDate(for: day.date, calendar: calendar) else { continue }
            await schedule(
                id: Identifier.prefix + String(offset),
                at: fireDate,
                day: day,
                now: now
            )
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Identifier.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    /// 08.00 local time on the forecast day: early enough to change plans, late enough not to
    /// be a 3am push about tomorrow's weather.
    private func morningAlertDate(for day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 8
        components.minute = 0
        return calendar.date(from: components)
    }

    private func schedule(id: String, at date: Date, day: DailyUV, now: Date) async {
        let delay = date.timeIntervalSince(now)
        guard delay > 0 else { return }

        let peak = Int(day.maxUVIndex.rounded())
        let content = UNMutableNotificationContent()
        content.title = String(localized: "UV will be high tomorrow")
        content.body = String(
            localized: "Peak UV \(peak). Take care in the sun between 11.00 and 16.00."
        )
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
