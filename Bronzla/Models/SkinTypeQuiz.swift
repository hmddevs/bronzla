import Foundation

/// The Fitzpatrick self-assessment questionnaire.
///
/// Pure domain: questions, scoring and the score-to-phototype mapping, with no UI and no
/// dependencies, so the classification can be tested directly.
///
/// The instrument is the standard self-report Fitzpatrick scale, trimmed from ten questions to
/// seven. The three dropped questions ask about *recent* sun habits, which measure current
/// adaptation rather than constitutional phototype. Including them makes a Turkish user who
/// has just spent a fortnight in Çeşme score a full type darker than they are, which would
/// then hand them a longer burn time than their skin can take. Fewer questions, safer answer.
enum SkinTypeQuiz {

    struct Option: Identifiable, Sendable {
        let id: Int
        let label: LocalizedStringResource
        /// 0 is the most sun-sensitive answer, 4 the least.
        var score: Int { id }
    }

    struct Question: Identifiable, Sendable {
        let id: String
        let prompt: LocalizedStringResource
        /// Practical cue that makes the question answerable without a mirror or a guess.
        let hint: LocalizedStringResource?
        let options: [Option]
    }

    // MARK: - Instrument

    static let questions: [Question] = [
        Question(
            id: "eyes",
            prompt: "What colour are your eyes?",
            hint: nil,
            options: [
                Option(id: 0, label: "Light blue, light grey or light green"),
                Option(id: 1, label: "Blue, grey or green"),
                Option(id: 2, label: "Hazel or light brown"),
                Option(id: 3, label: "Dark brown"),
                Option(id: 4, label: "Dark brown, close to black"),
            ]
        ),
        Question(
            id: "hair",
            prompt: "What is your natural hair colour?",
            hint: "Think of it undyed.",
            options: [
                Option(id: 0, label: "Red"),
                Option(id: 1, label: "Blond"),
                Option(id: 2, label: "Light brown"),
                Option(id: 3, label: "Dark brown"),
                Option(id: 4, label: "Black"),
            ]
        ),
        Question(
            id: "skin",
            prompt: "What colour is your skin where the sun does not reach?",
            hint: "Look at the inside of your arm. That shows your true skin colour all year round.",
            options: [
                Option(id: 0, label: "Reddish white"),
                Option(id: 1, label: "Very fair, pale"),
                Option(id: 2, label: "Light olive"),
                Option(id: 3, label: "Olive or wheat toned"),
                Option(id: 4, label: "Deep brown"),
            ]
        ),
        Question(
            id: "freckles",
            prompt: "Do you have freckles where the sun does not reach?",
            hint: nil,
            options: [
                Option(id: 0, label: "A great many"),
                Option(id: 1, label: "Quite a few"),
                Option(id: 2, label: "A few"),
                Option(id: 3, label: "Very little"),
                Option(id: 4, label: "None at all"),
            ]
        ),
        Question(
            id: "burn",
            prompt: "What happens if you stay in the sun a long time without protection?",
            hint: "Think of the first day you sunbathed this summer.",
            options: [
                Option(id: 0, label: "Turns painfully red, blisters and peels"),
                Option(id: 1, label: "Blisters, then peels"),
                Option(id: 2, label: "Turns red, sometimes peels"),
                Option(id: 3, label: "Turns slightly red"),
                Option(id: 4, label: "Never burns"),
            ]
        ),
        Question(
            id: "tan",
            prompt: "How much does your skin tan after a week in the sun?",
            hint: nil,
            options: [
                Option(id: 0, label: "Does not tan at all"),
                Option(id: 1, label: "Very little"),
                Option(id: 2, label: "Moderately"),
                Option(id: 3, label: "Tans easily"),
                Option(id: 4, label: "Tans very deeply"),
            ]
        ),
        Question(
            id: "face",
            prompt: "How sensitive is your face to the sun?",
            hint: nil,
            options: [
                Option(id: 0, label: "Very sensitive"),
                Option(id: 1, label: "Sensitive"),
                Option(id: 2, label: "Normal"),
                Option(id: 3, label: "Resilient"),
                Option(id: 4, label: "Not affected at all"),
            ]
        ),
    ]

    static var maximumScore: Int { questions.count * 4 }

    // MARK: - Scoring

    /// Maps a total score onto a phototype.
    ///
    /// Band edges are the standard scale's proportions rescaled to this instrument's 0 to 28
    /// range. The intervals are half open and ascending, so every score maps to exactly one
    /// type: 20 is the last type IV score, 21 the first type V.
    ///
    /// The bands sit slightly low on purpose. Classifying someone a shade more sun-sensitive
    /// than they are costs them an afternoon; the opposite costs them their skin.
    static func skinType(forScore score: Int) -> SkinType {
        switch score {
        case ..<6: .i
        case ..<11: .ii
        case ..<16: .iii
        case ..<21: .iv
        case ..<25: .v
        default: .vi
        }
    }

    /// Classifies a completed answer set.
    ///
    /// - Parameter answers: Question id to chosen option score.
    /// - Returns: The phototype, or `nil` if any question is unanswered. Partial answer sets
    ///   are refused rather than scored: three answers out of seven would systematically
    ///   classify everyone as type I.
    static func result(for answers: [String: Int]) -> SkinType? {
        guard answers.count == questions.count,
              questions.allSatisfy({ answers[$0.id] != nil })
        else { return nil }

        return skinType(forScore: answers.values.reduce(0, +))
    }
}
