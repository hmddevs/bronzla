import Foundation

/// Post-tan skin care guidance, tiered by `TanSession.burnRisk`.
///
/// A pure enum with static methods, per project convention: no dependencies, fully testable,
/// and the one place this app is allowed to tell a Turkish user that olive oil on a fresh burn
/// is folklore, not first aid.
enum AftercareAdvice {

    /// How serious the day's exposure was. Deliberately distinct from `UVCategory`, which
    /// describes ambient UV strength rather than what happened to a particular person's skin.
    enum Severity: Int, Comparable, Sendable {
        case routine, attentive, mild, serious

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Nearest point on the WHO scale, used only to borrow `Palette.colour(for:)` so the
        /// aftercare screen stays on the same colour language as the rest of the app.
        var uvCategory: UVCategory {
            switch self {
            case .routine: .low
            case .attentive: .high
            case .mild: .veryHigh
            case .serious: .extreme
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .routine: "Routine care"
            case .attentive: "Careful care"
            case .mild: "Mild burn"
            case .serious: "Severe burn"
            }
        }
    }

    /// One thing not to do, with the reason attached: a bare "yapmayın" is easy to ignore,
    /// a reason is what actually stops someone reaching for the olive oil bottle.
    struct Caution: Sendable {
        let action: LocalizedStringResource
        let reason: LocalizedStringResource
    }

    struct Advice: Sendable {
        let severity: Severity
        let title: LocalizedStringResource
        let steps: [LocalizedStringResource]
        let doNotDo: [Caution]
        /// Set only for the two highest tiers. The view renders this outside the step list, in
        /// its own prominent block, rather than burying "see a doctor" as line four of six.
        let prominentNotice: LocalizedStringResource?
    }

    /// Boundaries are half-open on the lower end: the boundary value itself belongs to the
    /// higher, more cautious tier. Reddening is "expected" at 1.0, not "about to happen".
    static func advice(forBurnRisk risk: Double) -> Advice {
        switch risk {
        case ..<0.5: routineCare
        case ..<1.0: attentiveCare
        case ..<1.5: mildBurnCare
        default: seriousBurnCare
        }
    }

    // MARK: - Tiers

    private static let routineCare = Advice(
        severity: .routine,
        title: "Burn risk is low today",
        steps: [
            "Take a lukewarm or cool shower; hot water dries the skin out further.",
            "Apply moisturiser after showering.",
            "Drink plenty of water to replace the fluid you lost in the sun.",
        ],
        doNotDo: [
            Caution(
                action: "Do not scrub hard with soap",
                reason: "The skin barrier is fragile after sun."
            ),
        ],
        prominentNotice: nil
    )

    private static let attentiveCare = Advice(
        severity: .attentive,
        title: "Your skin needs extra care",
        steps: [
            "Cool the skin with a cool shower or a compress.",
            "Apply pure aloe vera gel; it soothes and moisturises.",
            "Do not go out in the sun again today, stay in the shade.",
            "Drink plenty of water.",
        ],
        doNotDo: [
            Caution(
                action: "Do not apply olive oil",
                reason: "It is a well known remedy, but oil traps heat in the skin and makes things worse."
            ),
            Caution(
                action: "Do not apply vinegar or toothpaste",
                reason: "Both irritate the skin and give no real benefit."
            ),
        ],
        prominentNotice: nil
    )

    private static let mildBurnCare = Advice(
        severity: .mild,
        title: "There are signs of a mild burn",
        steps: [
            "Cool the area with a cool, damp cloth; repeat several times a day.",
            "Apply a gentle compress with yoghurt or chilled aloe vera gel.",
            "Apply a soothing, fragrance-free moisturiser.",
            "Protect the area from the sun and from tight clothing.",
            "Drink plenty of water; a burn makes the skin lose more fluid than usual.",
        ],
        doNotDo: [
            Caution(
                action: "Do not apply olive oil",
                reason: "It is a common belief, but oil traps heat and drives the burn deeper."
            ),
            Caution(
                action: "Do not let ice touch the skin directly",
                reason: "Extreme cold can do further damage to burnt skin."
            ),
            Caution(
                action: "Do not pop blisters",
                reason: "It breaks down the skin's natural protective barrier and raises the risk of infection."
            ),
        ],
        prominentNotice: "If the burn does not clear within 2 to 3 days, or blistering is widespread, see a doctor."
    )

    private static let seriousBurnCare = Advice(
        severity: .serious,
        title: "Severe burn: medical help may be needed",
        steps: [
            "Cool the area gently with cool water.",
            "Cover it with loose, cotton clothing.",
            "Drink plenty of water.",
            "If there is fever, shivering, dizziness or nausea, go to a healthcare facility without delay.",
        ],
        doNotDo: [
            Caution(
                action: "Do not apply olive oil",
                reason: "Contrary to this common belief, oil traps heat in the skin and makes the burn worse."
            ),
            Caution(
                action: "Do not apply ice or iced water",
                reason: "It does further harm to damaged skin."
            ),
            Caution(
                action: "Do not pop blisters yourself or peel the skin",
                reason: "It raises the risk of infection seriously."
            ),
        ],
        prominentNotice: "For a burn at this level, please see a doctor or a healthcare facility."
    )
}
