import SwiftData
import SwiftUI

/// Seven-question Fitzpatrick self-assessment.
///
/// One question per screen with auto-advance. A single seven-item form would be faster to
/// build and worse to answer: people skim long forms, and a skimmed phototype produces a burn
/// time that is wrong in the dangerous direction.
struct SkinTypeQuizView: View {
    /// Called with the classified type once the user accepts the result.
    var onComplete: (SkinType) -> Void
    var dismissOnCompletion = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var answers: [String: Int] = [:]
    @State private var index = 0
    @State private var result: SkinType?
    @State private var isShowingManualPicker = false

    private var questions: [SkinTypeQuiz.Question] { SkinTypeQuiz.questions }
    private var question: SkinTypeQuiz.Question { questions[index] }
    private var progress: Double { Double(index) / Double(questions.count) }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    SkinTypeResultView(skinType: result) {
                        onComplete(result)
                        if dismissOnCompletion {
                            dismiss()
                        }
                    } onRetake: {
                        withAnimation { reset() }
                    }
                } else {
                    quiz
                }
            }
            .navigationTitle("Your skin type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $isShowingManualPicker) {
                ManualSkinTypePicker { selected in
                    onComplete(selected)
                    if dismissOnCompletion {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Quiz

    private var quiz: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ProgressView(value: progress)
                .tint(Palette.colour(for: .moderate))
                .animation(reduceMotion ? nil : .smooth, value: progress)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Question \(index + 1) of \(questions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text(question.prompt)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let hint = question.hint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: Spacing.s) {
                ForEach(question.options) { option in
                    optionRow(option)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .id(question.id)
        .transition(.asymmetric(
            insertion: .push(from: .trailing),
            removal: .push(from: .leading)
        ))
    }

    private func optionRow(_ option: SkinTypeQuiz.Option) -> some View {
        let isSelected = answers[question.id] == option.score

        return Button {
            select(option)
        } label: {
            HStack(spacing: Spacing.m) {
                Text(option.label)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Palette.card,
                in: .rect(cornerRadius: Spacing.cardRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quiz.option.\(option.score)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if result == nil, index > 0 {
                Button("Back", systemImage: "chevron.left") {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { index -= 1 }
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if result == nil {
                Menu {
                    Button("I know my type") { isShowingManualPicker = true }
                    Button("Start again") { withAnimation { reset() } }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Actions

    private func select(_ option: SkinTypeQuiz.Option) {
        answers[question.id] = option.score

        // A brief pause so the selection registers visually before the screen moves. Without
        // it the tap feels like it went somewhere else.
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { advance() }
        }
    }

    private func advance() {
        if index + 1 < questions.count {
            index += 1
        } else {
            result = SkinTypeQuiz.result(for: answers)
        }
    }

    private func reset() {
        answers = [:]
        index = 0
        result = nil
    }
}

/// Escape hatch for users who already know their phototype. Faster than seven taps, and
/// people who know are usually right.
struct ManualSkinTypePicker: View {
    var onSelect: (SkinType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SkinType.allCases) { type in
                Button {
                    onSelect(type)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Type \(type.numeral) · \(String(localized: type.title))")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(type.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
            .navigationTitle("Choose a skin type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SkinTypeQuizView { _ in }
}
