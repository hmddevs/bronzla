import Foundation
import Testing
@testable import Bronzla

@Suite("Skin type quiz")
struct SkinTypeQuizTests {

    /// Builds an answer set where every question receives the same score.
    private func uniformAnswers(score: Int) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: SkinTypeQuiz.questions.map { ($0.id, score) })
    }

    @Test("Every question offers the full nought to four range exactly once")
    func instrumentIsWellFormed() {
        for question in SkinTypeQuiz.questions {
            #expect(question.options.map(\.score).sorted() == [0, 1, 2, 3, 4])
        }
    }

    @Test("Question identifiers are unique, so answers cannot overwrite each other")
    func questionIdentifiersAreUnique() {
        let ids = SkinTypeQuiz.questions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("The most sun-sensitive answers classify as type I")
    func allSensitiveAnswersGiveTypeOne() {
        #expect(SkinTypeQuiz.result(for: uniformAnswers(score: 0)) == .i)
    }

    @Test("The least sun-sensitive answers classify as type VI")
    func allTolerantAnswersGiveTypeSix() {
        #expect(SkinTypeQuiz.result(for: uniformAnswers(score: 4)) == .vi)
    }

    @Test("Middling answers land on type III or IV, the Turkish norm")
    func middlingAnswersGiveMediterraneanTypes() throws {
        let result = try #require(SkinTypeQuiz.result(for: uniformAnswers(score: 2)))
        #expect(result == .iii || result == .iv)
    }

    @Test("Classification never falls as the score rises")
    func classificationIsMonotonic() {
        var previous = 0
        for score in 0...SkinTypeQuiz.maximumScore {
            let type = SkinTypeQuiz.skinType(forScore: score)
            #expect(type.rawValue >= previous)
            previous = type.rawValue
        }
    }

    @Test("Every phototype is reachable, so no band is unreachable dead code")
    func everyTypeIsReachable() {
        let reachable = Set((0...SkinTypeQuiz.maximumScore).map { SkinTypeQuiz.skinType(forScore: $0) })
        #expect(reachable == Set(SkinType.allCases))
    }

    @Test("Incomplete answer sets are refused rather than scored")
    func partialAnswersAreRefused() {
        var answers = uniformAnswers(score: 3)
        answers.removeValue(forKey: SkinTypeQuiz.questions[0].id)
        // Scoring six of seven answers would silently classify this user a type lighter,
        // handing them a shorter session than they need. Refusing is the safe failure.
        #expect(SkinTypeQuiz.result(for: answers) == nil)
        #expect(SkinTypeQuiz.result(for: [:]) == nil)
    }

    @Test("Out-of-range scores clamp to the extremes rather than trapping")
    func outOfRangeScoresAreSafe() {
        #expect(SkinTypeQuiz.skinType(forScore: -5) == .i)
        #expect(SkinTypeQuiz.skinType(forScore: 999) == .vi)
    }

    @Test("Recommended SPF never rises as skin tolerance rises")
    func recommendedSPFTracksSensitivity() {
        var previous = Int.max
        for type in SkinType.allCases {
            #expect(type.recommendedSPF <= previous)
            previous = type.recommendedSPF
        }
    }
}
