import Foundation
import Testing
@testable import Bronzla

/// The exposure maths is the only part of Bronzla that can cause physical harm if it is
/// wrong, so it is tested against published figures rather than against itself.
@Suite("Exposure calculator")
struct ExposureCalculatorTests {

    // MARK: - Burn time

    @Test("Phototype III under UV 8 burns in 25 minutes")
    func burnTimeMatchesPublishedTable() throws {
        let burn = try #require(ExposureCalculator.timeToBurn(uvIndex: 8, skinType: .iii))
        // 300 J/m² / (8 × 0.025 W/m²) = 1500 s
        #expect(abs(burn.seconds - 1500) < 1)
    }

    @Test("Darker phototypes take longer to burn at identical UV")
    func burnTimeIncreasesWithPhototype() throws {
        var previous: Double = 0
        for type in SkinType.allCases {
            let burn = try #require(ExposureCalculator.timeToBurn(uvIndex: 9, skinType: type))
            #expect(burn.seconds > previous)
            previous = burn.seconds
        }
    }

    @Test("No burn time exists without UV", arguments: [0.0, -1.0])
    func noBurnTimeWithoutUV(uvIndex: Double) {
        #expect(ExposureCalculator.timeToBurn(uvIndex: uvIndex, skinType: .i) == nil)
    }

    @Test("Halving the UV index doubles the burn time")
    func burnTimeIsInverselyProportionalToUV() throws {
        let high = try #require(ExposureCalculator.timeToBurn(uvIndex: 10, skinType: .iv))
        let low = try #require(ExposureCalculator.timeToBurn(uvIndex: 5, skinType: .iv))
        #expect(abs(low.seconds - high.seconds * 2) < 0.001)
    }

    // MARK: - Sunscreen

    @Test("Bare skin gets no protection multiplier")
    func spfOneIsNeutral() {
        #expect(ExposureCalculator.protectionFactor(spf: 1) == 1)
    }

    @Test("SPF is discounted for real-world application")
    func spfIsDiscounted() {
        // Nominal 30 must never be treated as a 30x multiplier.
        let factor = ExposureCalculator.protectionFactor(spf: 30)
        #expect(factor < 30)
        #expect(factor > 1)
        // 1 + 29 × 0.5
        #expect(abs(factor - 15.5) < 0.001)
    }

    @Test("Invalid SPF values are clamped rather than inverting protection")
    func spfIsClamped() {
        #expect(ExposureCalculator.protectionFactor(spf: 0) == 1)
        #expect(ExposureCalculator.protectionFactor(spf: -10) == 1)
    }

    // MARK: - Recommended session

    @Test("Recommended session stays below the burn threshold")
    func recommendedSessionIsSubErythemal() throws {
        for type in SkinType.allCases {
            let burn = try #require(ExposureCalculator.timeToBurn(uvIndex: 7, skinType: type))
            let session = try #require(ExposureCalculator.recommendedSession(uvIndex: 7, skinType: type))
            #expect(session.seconds < burn.seconds)
        }
    }

    @Test("Recommended session is capped even for the most tolerant skin")
    func recommendedSessionIsCapped() throws {
        // Phototype VI at low UV with high SPF would otherwise model at many hours.
        let session = try #require(ExposureCalculator.recommendedSession(uvIndex: 1, skinType: .vi, spf: 50))
        #expect(session.seconds <= ExposureCalculator.maximumRecommendedSession.seconds)
    }

    // MARK: - Dose

    @Test("An hour at UV 8 delivers 720 J/m²")
    func doseOverConstantUV() {
        // 0.2 W/m² × 3600 s
        let dose = ExposureCalculator.dose(uvIndex: 8, over: .seconds(3600))
        #expect(abs(dose - 720) < 0.001)
    }

    @Test("Sunscreen reduces accumulated dose")
    func sunscreenReducesDose() {
        let bare = ExposureCalculator.dose(uvIndex: 8, over: .seconds(3600), spf: 1)
        let protected = ExposureCalculator.dose(uvIndex: 8, over: .seconds(3600), spf: 30)
        #expect(protected < bare)
    }

    @Test("Zero-length and reversed intervals contribute nothing")
    func degenerateIntervalsAreSafe() {
        #expect(ExposureCalculator.dose(uvIndex: 10, over: .zero) == 0)
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        #expect(ExposureCalculator.dose(across: [], from: now, to: now.addingTimeInterval(-3600)) == 0)
    }

    @Test("Dose across an hourly profile sums the overlapping portions only")
    func doseAcrossProfileClipsToInterval() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let samples = (0..<3).map { offset in
            HourlyUV(
                date: start.addingTimeInterval(Double(offset) * 3600),
                uvIndex: 8,
                temperature: Measurement(value: 30, unit: .celsius),
                isDaylight: true
            )
        }

        // Half an hour inside the first sample only.
        let partial = ExposureCalculator.dose(across: samples, from: start, to: start.addingTimeInterval(1800))
        #expect(abs(partial - 360) < 0.001)

        // The full three hours.
        let full = ExposureCalculator.dose(across: samples, from: start, to: start.addingTimeInterval(3 * 3600))
        #expect(abs(full - 2160) < 0.001)
    }

    @Test("Burn risk reaches 1.0 at exactly one MED")
    func burnRiskIsNormalisedToMED() {
        let risk = ExposureCalculator.burnRisk(dose: SkinType.iii.minimalErythemalDose, skinType: .iii)
        #expect(abs(risk - 1.0) < 0.001)
    }

    // MARK: - Vitamin D

    @Test("Vitamin D synthesis plateaus beyond one MED")
    func vitaminDPlateaus() {
        let atOneMED = ExposureCalculator.estimatedVitaminD(dose: 300, skinType: .iii)
        let atFiveMED = ExposureCalculator.estimatedVitaminD(dose: 1500, skinType: .iii)
        #expect(abs(atOneMED - atFiveMED) < 0.001)
    }

    @Test("Darker phototypes synthesise less for the same relative dose")
    func vitaminDAccountsForMelanin() {
        let lighter = ExposureCalculator.estimatedVitaminD(dose: 250, skinType: .ii)
        let darker = ExposureCalculator.estimatedVitaminD(dose: 1000, skinType: .vi)
        // Both received exactly one MED, so only melanin efficiency separates them.
        #expect(darker < lighter)
    }

    @Test("No exposure produces no vitamin D")
    func vitaminDRequiresExposure() {
        #expect(ExposureCalculator.estimatedVitaminD(dose: 0, skinType: .iii) == 0)
    }

    // MARK: - Session structure

    @Test("Flip lands exactly halfway through the session")
    func flipIsHalfway() {
        let flip = ExposureCalculator.flipInterval(for: .seconds(1800))
        #expect(abs(flip.seconds - 900) < 0.001)
    }
}

@Suite("UV category thresholds")
struct UVCategoryTests {

    @Test(
        "WHO bands map to the published thresholds",
        arguments: [
            (0.0, UVCategory.low), (2.9, .low),
            (3.0, .moderate), (5.9, .moderate),
            (6.0, .high), (7.9, .high),
            (8.0, .veryHigh), (10.9, .veryHigh),
            (11.0, .extreme), (15.0, .extreme),
        ]
    )
    func bandsMatchWHO(uvIndex: Double, expected: UVCategory) {
        #expect(UVCategory(uvIndex: uvIndex) == expected)
    }

    @Test("Protection is advised from the moderate band upwards")
    func protectionThreshold() {
        #expect(UVCategory.low.requiresProtection == false)
        #expect(UVCategory.moderate.requiresProtection)
        #expect(UVCategory.extreme.requiresProtection)
    }
}
