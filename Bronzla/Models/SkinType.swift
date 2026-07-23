import Foundation

/// Fitzpatrick skin phototypes, adapted for a Turkish and wider Mediterranean audience.
///
/// The Fitzpatrick scale was devised in 1975 to predict how skin responds to UV. It is the
/// standard the dermatological literature uses for minimal erythemal dose (MED), which is why
/// `ExposureCalculator` keys off it. Types III and IV are by far the most common in Türkiye,
/// so the copy leads with familiar reference points rather than northern European ones.
enum SkinType: Int, CaseIterable, Codable, Sendable, Identifiable {
    case i = 1, ii, iii, iv, v, vi

    var id: Int { rawValue }

    /// Roman numeral shown in the UI. Deliberately not localised: the scale is universal.
    var numeral: String {
        switch self {
        case .i: "I"
        case .ii: "II"
        case .iii: "III"
        case .iv: "IV"
        case .v: "V"
        case .vi: "VI"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .i: "Very fair"
        case .ii: "Fair"
        case .iii: "Light olive"
        case .iv: "Olive"
        case .v: "Brown"
        case .vi: "Deep brown"
        }
    }

    /// How this skin behaves in the sun, in plain language.
    var summary: LocalizedStringResource {
        switch self {
        case .i: "Always burns, never tans."
        case .ii: "Burns easily, tans with difficulty."
        case .iii: "Sometimes burns, tans gradually."
        case .iv: "Rarely burns, tans easily."
        case .v: "Very rarely burns, tans very easily."
        case .vi: "Almost never burns, always darkens."
        }
    }

    /// A concrete, recognisable description for Turkish users.
    var detail: LocalizedStringResource {
        switch self {
        case .i:
            "Very fair skin, usually red or blond hair, blue or green eyes, plenty of freckles. Uncommon in Türkiye."
        case .ii:
            "Fair skin, blond or light brown hair, light eyes. Common along the Black Sea and in Thrace."
        case .iii:
            "Light olive skin, brown hair, hazel or brown eyes. One of the two most common types in Türkiye."
        case .iv:
            "Olive toned skin, dark brown hair and eyes. The most common type along the Mediterranean and Aegean coasts."
        case .v:
            "Naturally brown skin, near black hair and dark eyes. Common in the southeast."
        case .vi:
            "Dark brown skin, black hair and eyes. Reddening in the sun is very rare."
        }
    }

    /// Minimal erythemal dose: the erythemally weighted UV energy, in joules per square metre,
    /// that produces just-perceptible reddening 24 hours after exposure on unadapted skin.
    ///
    /// Values are the midpoints of the ranges reported in the clinical literature
    /// (Fitzpatrick 1988; Sayre et al.). They are population averages, not personal
    /// measurements, which is why every surface that consumes them carries a disclaimer.
    var minimalErythemalDose: Double {
        switch self {
        case .i: 200
        case .ii: 250
        case .iii: 300
        case .iv: 450
        case .v: 600
        case .vi: 1000
        }
    }

    /// Highest SPF worth recommending as a starting point for this phototype.
    var recommendedSPF: Int {
        switch self {
        case .i, .ii: 50
        case .iii, .iv: 30
        case .v, .vi: 20
        }
    }
}
