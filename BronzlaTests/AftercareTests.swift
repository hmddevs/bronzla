import Foundation
import Testing
@testable import Bronzla

@Suite("Aftercare advice")
struct AftercareAdviceTests {

    // MARK: - Tier boundaries

    @Test("Below 0.5 is routine care")
    func belowRoutineBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 0.49).severity == .routine)
    }

    @Test("0.5 is the lower edge of attentive care, not routine")
    func atRoutineBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 0.5).severity == .attentive)
    }

    @Test("Below 1.0 is attentive care")
    func belowMildBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 0.99).severity == .attentive)
    }

    @Test("1.0 is the lower edge of mild burn care")
    func atMildBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 1.0).severity == .mild)
    }

    @Test("Below 1.5 is mild burn care")
    func belowSeriousBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 1.49).severity == .mild)
    }

    @Test("1.5 is the lower edge of serious burn care")
    func atSeriousBoundary() {
        #expect(AftercareAdvice.advice(forBurnRisk: 1.5).severity == .serious)
    }

    @Test("Zero risk is still routine care, never nil")
    func zeroRiskIsRoutine() {
        #expect(AftercareAdvice.advice(forBurnRisk: 0).severity == .routine)
    }

    // MARK: - Monotonicity

    @Test("Severity rises monotonically with burn risk")
    func severityRisesWithRisk() {
        let samples: [Double] = [0, 0.3, 0.5, 0.8, 1.0, 1.2, 1.5, 2.5]
        let severities = samples.map { AftercareAdvice.advice(forBurnRisk: $0).severity }
        for pair in zip(severities, severities.dropFirst()) {
            #expect(pair.0 <= pair.1)
        }
    }

    // MARK: - Turkish folk remedies

    @Test(
        "Olive oil is warned against for every tier that involves actual skin damage",
        arguments: [0.6, 1.1, 1.6]
    )
    func oliveOilWarnedAgainstOnBurnTiers(risk: Double) {
        let advice = AftercareAdvice.advice(forBurnRisk: risk)
        #expect(advice.doNotDo.contains { "\($0.action)".contains("olive oil") })
    }

    @Test("The two highest tiers carry a prominent doctor notice")
    func highestTiersCarryDoctorNotice() {
        #expect(AftercareAdvice.advice(forBurnRisk: 1.2).prominentNotice != nil)
        #expect(AftercareAdvice.advice(forBurnRisk: 2.0).prominentNotice != nil)
    }

    @Test("Routine and attentive tiers have no prominent doctor notice")
    func lowTiersHaveNoDoctorNotice() {
        #expect(AftercareAdvice.advice(forBurnRisk: 0.2).prominentNotice == nil)
        #expect(AftercareAdvice.advice(forBurnRisk: 0.7).prominentNotice == nil)
    }
}

@Suite("Daily UV alert day selection")
struct DailyUVAlertSchedulerTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let today = Date(timeIntervalSince1970: 1_753_000_000) // an arbitrary fixed instant

    private func day(offsetDays: Int, maxUVIndex: Double) -> DailyUV {
        let date = calendar.date(byAdding: .day, value: offsetDays, to: today)!
        return DailyUV(
            date: date,
            maxUVIndex: maxUVIndex,
            highTemperature: Measurement(value: 28, unit: .celsius),
            lowTemperature: Measurement(value: 18, unit: .celsius),
            conditionSymbol: "sun.max",
            sunrise: nil,
            sunset: nil
        )
    }

    @Test("A day with peak UV 8 or above qualifies")
    func highUVDayQualifies() {
        let days = [day(offsetDays: 1, maxUVIndex: 8)]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.count == 1)
    }

    @Test("A day below the threshold does not qualify")
    func lowUVDayDoesNotQualify() {
        let days = [day(offsetDays: 1, maxUVIndex: 7.9)]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.isEmpty)
    }

    @Test("Today itself never qualifies, only future days")
    func todayIsExcluded() {
        let days = [day(offsetDays: 0, maxUVIndex: 11)]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.isEmpty)
    }

    @Test("Nothing beyond seven days out qualifies, however high the forecast")
    func lookaheadIsCappedAtSevenDays() {
        let days = [day(offsetDays: 8, maxUVIndex: 12)]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.isEmpty)
    }

    @Test("The seventh day out still qualifies, at the edge of the window")
    func seventhDayStillQualifies() {
        let days = [day(offsetDays: 7, maxUVIndex: 9)]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.count == 1)
    }

    @Test("A mixed week returns only the qualifying days, in date order")
    func mixedWeekFiltersCorrectly() {
        let days = [
            day(offsetDays: 3, maxUVIndex: 9),
            day(offsetDays: 1, maxUVIndex: 3),
            day(offsetDays: 2, maxUVIndex: 8),
        ]
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.map(\.maxUVIndex) == [8, 9])
    }

    @Test("No day qualifying returns an empty list, not a crash")
    func noQualifyingDayIsEmpty() {
        let days = (1...7).map { day(offsetDays: $0, maxUVIndex: 4) }
        let qualifying = DailyUVAlertScheduler.qualifyingDays(in: days, from: today, calendar: calendar)
        #expect(qualifying.isEmpty)
    }

    @Test("Disabled by default")
    func disabledByDefault() {
        let suiteName = "bronzla.tests.dailyUVAlerts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let scheduler = DailyUVAlertScheduler(defaults: defaults)
        #expect(!scheduler.isEnabled)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
