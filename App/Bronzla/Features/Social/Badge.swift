import Foundation

/// Earned badges.
///
/// Every one of these is earned by restraint rather than exposure. There is deliberately no
/// badge for longest session, darkest tan or most hours: those would be the app applauding the
/// exact behaviour it exists to moderate.
enum Badge: String, CaseIterable, Identifiable, Sendable {
    case firstSession
    case disciplined
    case earlyBird
    case shadeMaster
    case perfectWeek
    case perfectSeason
    case protector

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .firstSession: "First session"
        case .disciplined: "Disciplined"
        case .earlyBird: "Early bird"
        case .shadeMaster: "Shade master"
        case .perfectWeek: "Flawless week"
        case .perfectSeason: "Flawless season"
        case .protector: "Protected"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .firstSession: "You recorded your first session."
        case .disciplined: "10 sessions, and you never went over the limit."
        case .earlyBird: "You completed 5 sessions before midday."
        case .shadeMaster: "You did not burn once for a whole month."
        case .perfectWeek: "7 days in a row, zero burns."
        case .perfectSeason: "30 sessions, zero burns."
        case .protector: "You used sunscreen in 20 sessions."
        }
    }

    var symbol: String {
        switch self {
        case .firstSession: "sun.min.fill"
        case .disciplined: "checkmark.seal.fill"
        case .earlyBird: "sunrise.fill"
        case .shadeMaster: "umbrella.fill"
        case .perfectWeek: "calendar.badge.checkmark"
        case .perfectSeason: "trophy.fill"
        case .protector: "shield.lefthalf.filled"
        }
    }

    /// Which badges a session history has earned. Pure, so it is testable directly.
    static func earned(from sessions: [TanSession], referenceDate: Date = .now, calendar: Calendar = .current) -> [Badge] {
        guard !sessions.isEmpty else { return [] }

        let clean = sessions.filter { $0.burnRisk < 1.0 }
        let protected = sessions.filter { $0.spf > 1 }
        let score = BronzScore.make(from: sessions, referenceDate: referenceDate, calendar: calendar)

        // Sessions that finished before noon, which is how you tan on the Turkish coast without
        // meeting the afternoon peak.
        let morning = sessions.filter { calendar.component(.hour, from: $0.endedAt) < 12 }

        let monthAgo = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        let recent = sessions.filter { $0.startedAt >= monthAgo }
        let noBurnsThisMonth = !recent.isEmpty && recent.allSatisfy { $0.burnRisk < 1.0 }

        var earned: [Badge] = [.firstSession]
        if clean.count >= 10, score.burnCount == 0 { earned.append(.disciplined) }
        if morning.count >= 5 { earned.append(.earlyBird) }
        if noBurnsThisMonth, recent.count >= 4 { earned.append(.shadeMaster) }
        if score.longestStreak >= 7, score.burnCount == 0 { earned.append(.perfectWeek) }
        if sessions.count >= 30, score.burnCount == 0 { earned.append(.perfectSeason) }
        if protected.count >= 20 { earned.append(.protector) }

        return earned
    }
}
