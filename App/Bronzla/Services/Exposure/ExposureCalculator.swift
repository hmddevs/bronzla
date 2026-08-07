import Foundation

/// Sun exposure maths. Pure, synchronous, dependency-free and therefore fully unit-testable.
///
/// This is the one part of Bronzla that can cause physical harm if it is wrong, so it holds no
/// state, touches no network, reads no clock it was not handed, and every constant below is
/// traceable to a published source. Do not add convenience here that requires a dependency.
///
/// Model
/// -----
/// The UV index is defined so that one unit equals 25 mW/m² of erythemally weighted irradiance.
/// Reddening begins once accumulated dose reaches the skin's minimal erythemal dose (MED):
///
///     irradiance (W/m²) = uvIndex × 0.025
///     time to burn (s)  = MED (J/m²) / irradiance × sunscreenFactor
///
/// Worked example: phototype III (MED 300) under UV 8, no sunscreen
///     irradiance = 8 × 0.025 = 0.2 W/m²
///     burn time  = 300 / 0.2 = 1500 s = 25 minutes
///
/// which agrees with published erythema tables.
enum ExposureCalculator {

    // MARK: - Constants

    /// Erythemally weighted irradiance represented by one UV index unit, in W/m².
    /// WHO/WMO definition. Not a tunable.
    static let irradiancePerUVIndexUnit: Double = 0.025

    /// Fraction of MED treated as a safe session target. Staying below one MED is what
    /// separates tanning from burning: melanogenesis is stimulated well before reddening.
    /// 0.6 leaves headroom for the model's own error, which is considerable.
    static let safeSessionFraction: Double = 0.6

    /// Sunscreen never performs at its label value in the field. Real-world application is
    /// roughly a third of the 2 mg/cm² used in laboratory testing, so effective protection is
    /// far below nominal SPF. Applying this haircut is the honest choice; the alternative is
    /// telling someone with SPF 50 that they have 20 hours.
    static let realWorldSunscreenEfficiency: Double = 0.5

    /// Sessions longer than this are not modelled: the linear-dose assumption stops holding,
    /// and no responsible app should suggest six hours in the sun regardless of phototype.
    static let maximumRecommendedSession: Duration = .seconds(3 * 60 * 60)

    // MARK: - Burn time

    /// Time until just-perceptible reddening at a constant UV index.
    ///
    /// - Parameters:
    ///   - uvIndex: Current UV index. Values at or below zero mean no erythemal risk.
    ///   - skinType: Fitzpatrick phototype supplying the MED.
    ///   - spf: Nominal sun protection factor. Use 1 for bare skin. Values below 1 are clamped.
    /// - Returns: Time to one MED, or `nil` when the UV index cannot cause erythema.
    static func timeToBurn(uvIndex: Double, skinType: SkinType, spf: Int = 1) -> Duration? {
        let irradiance = uvIndex * irradiancePerUVIndexUnit
        guard irradiance > 0 else { return nil }

        let seconds = skinType.minimalErythemalDose / irradiance * protectionFactor(spf: spf)
        return .seconds(seconds)
    }

    /// Recommended session length: a sub-erythemal fraction of the burn time, capped.
    ///
    /// - Returns: `nil` when there is no meaningful UV to tan in.
    static func recommendedSession(uvIndex: Double, skinType: SkinType, spf: Int = 1) -> Duration? {
        guard let burn = timeToBurn(uvIndex: uvIndex, skinType: skinType, spf: spf) else { return nil }
        let target = burn.seconds * safeSessionFraction
        return .seconds(min(target, maximumRecommendedSession.seconds))
    }

    /// Effective multiplier a sunscreen contributes to time-to-burn, after the realism haircut.
    /// SPF 1 (bare skin) is exactly 1: no haircut applies where there is nothing to degrade.
    static func protectionFactor(spf: Int) -> Double {
        let nominal = Double(max(spf, 1))
        guard nominal > 1 else { return 1 }
        return 1 + (nominal - 1) * realWorldSunscreenEfficiency
    }

    // MARK: - Accumulated dose

    /// Erythemal dose accumulated over an interval at a constant UV index, in J/m².
    static func dose(uvIndex: Double, over duration: Duration, spf: Int = 1) -> Double {
        guard uvIndex > 0, duration > .zero else { return 0 }
        let irradiance = uvIndex * irradiancePerUVIndexUnit
        return irradiance * duration.seconds / protectionFactor(spf: spf)
    }

    /// Accumulated dose across a varying UV profile, integrated per hourly sample.
    /// Used by the tracker when a session straddles the afternoon peak.
    ///
    /// Known limitation: the integration applies a single SPF across the whole window. Swimming
    /// or towelling removes sunscreen, so for the stretch between leaving the water and
    /// reapplying, the real protection factor is closer to 1 and this figure understates the
    /// dose received. Modelling that properly would need a timestamped protection profile; for
    /// 1.0.1 the mitigation is behavioural instead, an immediate reapply prompt on water exit
    /// (`TimerState.acknowledgeWaterExit(at:)`) that keeps the unprotected window short.
    static func dose(across samples: [HourlyUV], from start: Date, to end: Date, spf: Int = 1) -> Double {
        guard end > start else { return 0 }
        return samples.reduce(into: 0.0) { total, sample in
            let sampleEnd = sample.date.addingTimeInterval(3600)
            let overlapStart = max(sample.date, start)
            let overlapEnd = min(sampleEnd, end)
            guard overlapEnd > overlapStart else { return }
            total += dose(
                uvIndex: sample.uvIndex,
                over: .seconds(overlapEnd.timeIntervalSince(overlapStart)),
                spf: spf
            )
        }
    }

    /// Dose expressed as a fraction of the phototype's MED. 1.0 means reddening is expected.
    static func burnRisk(dose: Double, skinType: SkinType) -> Double {
        guard skinType.minimalErythemalDose > 0 else { return 0 }
        return dose / skinType.minimalErythemalDose
    }

    // MARK: - Vitamin D

    /// Very rough vitamin D synthesis estimate, in international units.
    ///
    /// Deliberately crude, and labelled as such wherever it is shown. Real synthesis depends on
    /// age, body composition, baseline serum 25(OH)D, and prior exposure, none of which this app
    /// knows. The plateau is real: synthesis self-limits near one MED as previtamin D
    /// photoisomerises to inert products, so more sun does not mean more vitamin D.
    ///
    /// - Parameter exposedBodyFraction: Skin exposed, 0 to 1. Swimwear is roughly 0.6,
    ///   shorts and a t-shirt roughly 0.25.
    static func estimatedVitaminD(
        dose: Double,
        skinType: SkinType,
        exposedBodyFraction: Double = 0.6
    ) -> Double {
        guard dose > 0 else { return 0 }

        // Synthesis saturates at approximately one MED regardless of further exposure.
        let fractionOfMED = min(burnRisk(dose: dose, skinType: skinType), 1.0)
        // Whole-body exposure to one MED yields roughly 15,000 IU in lighter phototypes.
        let wholeBodyYieldAtOneMED: Double = 15_000
        let coverage = min(max(exposedBodyFraction, 0), 1)

        // Melanin competes with 7-dehydrocholesterol for the same photons, so darker
        // phototypes need materially longer exposure for the same yield. The multipliers below
        // are this app's own model estimates, not figures drawn from a published clinical
        // source: they encode the direction of the effect described in the literature, but the
        // exact magnitudes have not been validated against a trial. Treat any vitamin D figure
        // derived from them as an indicative estimate, never a clinical one.
        let melaninEfficiency: Double
        switch skinType {
        case .i, .ii: melaninEfficiency = 1.0
        case .iii, .iv: melaninEfficiency = 0.8
        case .v: melaninEfficiency = 0.55
        case .vi: melaninEfficiency = 0.4
        }

        return fractionOfMED * wholeBodyYieldAtOneMED * coverage * melaninEfficiency
    }

    // MARK: - Session structure

    /// When to turn over, so both sides receive an even dose. Even splits beat clever ones:
    /// people remember "halfway".
    static func flipInterval(for session: Duration) -> Duration {
        .seconds(session.seconds / 2)
    }

    /// Sunscreen reapplication interval. Every product label and every dermatology body agrees
    /// on two hours, sooner after swimming or towelling. Fixed, never derived.
    static let reapplyInterval: Duration = .seconds(2 * 60 * 60)

    // MARK: - Sunscreen strength

    /// The minimum SPF to use, by UV level. A floor, never a dial: this is deliberately not a
    /// function of session length, because sunscreen must not be used to buy more time in the
    /// sun. The dermatology bodies are consistent here, so the ladder has exactly two rungs.
    ///
    /// SPF 15 is the lowest protection that should ever be used; SPF 30 or above is the
    /// recommendation once UV reaches the moderate band, blocking around 97% of UVB.
    /// Sources: Türk Dermatoloji Derneği, NHS, AAD, British Association of Dermatologists.
    static func recommendedMinimumSPF(uvIndex: Double) -> Int {
        uvIndex < 3 ? 15 : 30
    }
}

extension Duration {
    /// Whole and fractional seconds as a `Double`. `components` is (seconds, attoseconds).
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
