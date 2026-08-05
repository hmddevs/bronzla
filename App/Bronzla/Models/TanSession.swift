import Foundation
import SwiftData

/// One logged time in the sun.
///
/// Dose is stored rather than recomputed, because the UV profile that produced it is a
/// forecast that will have been revised by the time anyone opens the history screen.
/// A session's record should not change retroactively.
@Model
final class TanSession {
    var startedAt: Date
    var endedAt: Date
    var placeName: String
    var spf: Int
    var skinTypeRawValue: Int
    /// Erythemal dose in J/m², computed at the time from the UV profile then in force.
    var erythemalDose: Double
    /// Peak UV index observed during the session, for the history summary.
    var peakUVIndex: Double
    var notes: String
    /// Photos are kept out of the store body: SwiftData is not a blob store and a dozen
    /// full-resolution photos would bloat every fetch.
    var photoFileNames: [String]
    /// Who ran this session. Optional so sessions logged before multi-profile support keep
    /// working unattributed rather than being orphaned or requiring a data migration.
    var profile: UserProfile?

    init(
        startedAt: Date,
        endedAt: Date,
        placeName: String,
        spf: Int,
        skinType: SkinType,
        erythemalDose: Double,
        peakUVIndex: Double,
        notes: String = "",
        photoFileNames: [String] = [],
        profile: UserProfile? = nil
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.placeName = placeName
        self.spf = spf
        self.skinTypeRawValue = skinType.rawValue
        self.erythemalDose = erythemalDose
        self.peakUVIndex = peakUVIndex
        self.notes = notes
        self.photoFileNames = photoFileNames
        self.profile = profile
    }

    var skinType: SkinType {
        get { SkinType(rawValue: skinTypeRawValue) ?? .iii }
        set { skinTypeRawValue = newValue.rawValue }
    }

    var duration: Duration { .seconds(endedAt.timeIntervalSince(startedAt)) }

    /// Fraction of a minimal erythemal dose received. At or above 1.0 reddening is expected.
    var burnRisk: Double {
        ExposureCalculator.burnRisk(dose: erythemalDose, skinType: skinType)
    }
}
