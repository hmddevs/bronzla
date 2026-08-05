import Foundation
import HealthKit
import OSLog

/// Writes finished sessions to Apple Health.
///
/// Write-only, and deliberately so. Bronzla has no use for the user's heart rate or weight, and
/// asking for read access it would never exercise is the kind of over-broad permission request
/// that teaches people to distrust prompts. Health becomes the durable home for this data; the
/// app's own store is just its working copy.
///
/// Every method is a no-op when HealthKit is unavailable or permission was refused. Logging a
/// session must never fail because Health said no.
@MainActor
final class HealthStore {
    static let shared = HealthStore()

    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "Health")
    private let store = HKHealthStore()

    /// User-facing switch, defaulting off. Health writing is opt-in; a paid app that quietly
    /// pushes data into Health on first launch has not earned the trust it is spending.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private static let enabledKey = "bronzla.health.enabled"

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let daylight = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) {
            types.insert(daylight)
        }
        if let uv = HKQuantityType.quantityType(forIdentifier: .uvExposure) {
            types.insert(uv)
        }
        return types
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests write access. Returns false when unavailable or refused, and callers carry on.
    @discardableResult
    func requestAuthorisation() async -> Bool {
        guard isAvailable, !writeTypes.isEmpty else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            return true
        } catch {
            logger.notice("Health authorisation failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Saves a session as time in daylight plus a UV exposure sample.
    ///
    /// - Note: UV exposure in HealthKit is a unitless index count, not a dose. The erythemal
    ///   dose this app computes has no HealthKit equivalent, so the peak index is recorded
    ///   instead of inventing a conversion that would look authoritative and mean nothing.
    func save(session: TanSession) async {
        guard isEnabled, isAvailable else { return }

        var samples: [HKQuantitySample] = []

        if let daylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) {
            samples.append(
                HKQuantitySample(
                    type: daylightType,
                    quantity: HKQuantity(unit: .minute(), doubleValue: session.duration.seconds / 60),
                    start: session.startedAt,
                    end: session.endedAt
                )
            )
        }

        if let uvType = HKQuantityType.quantityType(forIdentifier: .uvExposure) {
            samples.append(
                HKQuantitySample(
                    type: uvType,
                    quantity: HKQuantity(unit: .count(), doubleValue: session.peakUVIndex),
                    start: session.startedAt,
                    end: session.endedAt
                )
            )
        }

        guard !samples.isEmpty else { return }

        do {
            try await store.save(samples)
        } catch {
            // The session is already safely in SwiftData, so a Health failure costs the user
            // nothing. Logged rather than surfaced, because an alert here would be noise.
            logger.notice("Could not write session to Health: \(error.localizedDescription, privacy: .public)")
        }
    }
}
