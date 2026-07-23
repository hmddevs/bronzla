import Foundation
import SwiftData

/// A local profile: originally the single user, now one of possibly several family members
/// sharing a device on a beach holiday. Persisted with SwiftData so it survives reinstall-free
/// upgrades.
@Model
final class UserProfile {
    /// Stored as the Fitzpatrick raw value: SwiftData handles `Int` natively, and an enum
    /// stored raw survives a future case addition without a schema migration.
    var skinTypeRawValue: Int
    var defaultSPF: Int
    /// Proportion of skin typically exposed, 0 to 1. Feeds the vitamin D estimate.
    var exposedBodyFraction: Double
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    /// Display name, e.g. "Ben" or a family member's first name.
    ///
    /// Declared with an inline default (rather than only an `init` default) so SwiftData's
    /// automatic lightweight migration can add this column to a store created before
    /// multi-profile support without a manual migration plan.
    var name: String = ""
    /// Convenience cache of "this is the one `ActiveProfileStore` currently points at". The
    /// store's `UserDefaults` entry is the source of truth; this flag exists so a `@Query`
    /// can filter or sort by it without reading `UserDefaults` from inside a view.
    var isActive: Bool = false
    /// Hex string ("#RRGGBB") from `ProfilePalette.swatches`, so profiles are distinguishable
    /// at a glance without depending on the system colour picker's unconstrained range.
    var colourHex: String = "#FF9500"

    init(
        skinType: SkinType = .iii,
        defaultSPF: Int = 30,
        exposedBodyFraction: Double = 0.6,
        hasCompletedOnboarding: Bool = false,
        name: String = "",
        isActive: Bool = false,
        colourHex: String = "#FF9500"
    ) {
        self.skinTypeRawValue = skinType.rawValue
        self.defaultSPF = defaultSPF
        self.exposedBodyFraction = exposedBodyFraction
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = .now
        self.name = name
        self.isActive = isActive
        self.colourHex = colourHex
    }

    var skinType: SkinType {
        get { SkinType(rawValue: skinTypeRawValue) ?? .iii }
        set { skinTypeRawValue = newValue.rawValue }
    }
}
