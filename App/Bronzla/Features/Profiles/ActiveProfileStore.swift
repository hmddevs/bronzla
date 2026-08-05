import Foundation
import Observation
import SwiftData

/// Which family member is currently using the app; persisted across launches.
///
/// `UserDefaults` holds the encoded `PersistentIdentifier`, which is the single source of
/// truth. `UserProfile.isActive` is kept in step for convenience (a `@Query` can filter or
/// sort on it without reaching into `UserDefaults`) but this store owns the decision, so a
/// stale flag left behind by a deleted profile can never leave two profiles active, or none.
@MainActor
@Observable
final class ActiveProfileStore {
    private static let storageKey = "com.hmdcorp.bronzla.activeProfileIdentifier"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var storedIdentifier: PersistentIdentifier? {
        get {
            guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
            return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Self.storageKey)
                return
            }
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Resolves the active profile from a freshly fetched list. Falls back to the first
    /// profile when nothing is stored yet, or the stored profile was deleted, so callers never
    /// have to handle an empty active slot themselves.
    func profile(in profiles: [UserProfile]) -> UserProfile? {
        ActiveProfileResolution.resolve(profiles: profiles, storedIdentifier: storedIdentifier)
    }

    /// Marks `profile` active and persists the choice. Also flips `isActive` across `profiles`
    /// so anything reading the stored flag rather than this store still sees one consistent
    /// winner.
    func setActive(_ profile: UserProfile, in profiles: [UserProfile]) {
        storedIdentifier = profile.persistentModelID
        ActiveProfileResolution.applyActive(profile, to: profiles)
    }
}

/// Pure profile-selection logic, extracted so it is testable with plain, unsaved
/// `UserProfile` instances and no `ModelContainer`.
enum ActiveProfileResolution {
    static func resolve(profiles: [UserProfile], storedIdentifier: PersistentIdentifier?) -> UserProfile? {
        if let storedIdentifier, let match = profiles.first(where: { $0.persistentModelID == storedIdentifier }) {
            return match
        }
        return profiles.first
    }

    static func applyActive(_ profile: UserProfile, to profiles: [UserProfile]) {
        for candidate in profiles {
            candidate.isActive = candidate.persistentModelID == profile.persistentModelID
        }
    }

    /// The last remaining profile may never be deleted: the app has no "no profile" state, and
    /// `RootView`'s onboarding gate assumes at least one always exists.
    static func canDelete(_ profile: UserProfile, from profiles: [UserProfile]) -> Bool {
        profiles.count > 1
    }

    /// Which profile should become active once `deleted` is removed. `nil` when the deleted
    /// profile was not the active one, since the active profile is then untouched.
    static func profileToActivateAfterDeleting(_ deleted: UserProfile, from profiles: [UserProfile]) -> UserProfile? {
        guard deleted.isActive else { return nil }
        return profiles.first { $0.persistentModelID != deleted.persistentModelID }
    }

    /// A profile created before multi-profile support has an empty `name` and `isActive ==
    /// false`; both still work (`resolve` falls back to `profiles.first`), but this gives it a
    /// sensible identity so the switcher reads correctly from the first run rather than the
    /// second. Idempotent and safe to call on every appearance: a named, already-active profile
    /// is left untouched, and nothing runs at all once there is more than one profile.
    static func migrateLegacyProfileIfNeeded(_ profiles: [UserProfile]) {
        guard profiles.count == 1, let profile = profiles.first else { return }
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.name = String(localized: "Me")
        }
        if !profile.isActive {
            profile.isActive = true
        }
    }
}
