import SwiftUI

/// First-run flow: a short intro, the existing skin-type quiz, then a concise wizard for
/// the core app actions.
struct OnboardingFlowView: View {
    var onSkinTypeSelected: (SkinType) -> Void
    var onComplete: () -> Void

    @State private var stage: Stage = .intro
    @State private var selectedSkinType: SkinType = .iii

    var body: some View {
        Group {
            switch stage {
            case .intro:
                OnboardingIntroView {
                    stage = .quiz
                }
            case .quiz:
                SkinTypeQuizView(onComplete: { skinType in
                    selectedSkinType = skinType
                    onSkinTypeSelected(skinType)
                    stage = .wizard
                }, dismissOnCompletion: false)
            case .wizard:
                OnboardingWizardView(skinType: selectedSkinType) {
                    onComplete()
                }
            }
        }
    }

    private enum Stage {
        case intro
        case quiz
        case wizard
    }
}

/// The very first screen. It sets expectations and explains why the onboarding exists.
private struct OnboardingIntroView: View {
    var onContinue: () -> Void

    private let highlights: [(symbol: String, title: LocalizedStringResource, body: LocalizedStringResource)] = [
        ("sun.max.fill", "Get today’s safe time", "Bronzla turns the UV index, your skin type and your SPF into one clear number."),
        ("timer", "Run a real session timer", "Start a timer, get reminders, and stop before the day turns into a burn."),
        ("person.2.fill", "Keep family profiles separate", "Each person on the device keeps their own skin type and defaults.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Welcome to Bronzla")
                        .font(.largeTitle.weight(.semibold))

                    Text("A short setup keeps the app accurate from the first session.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Spacing.m) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { _, item in
                        onboardingCard(symbol: item.symbol, title: item.title, body: item.body)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("What happens next")
                        .font(.headline)
                    Text("You will answer the skin-type quiz, then Bronzla will show you how to use the app in three quick steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardSurface()

                MedicalDisclaimer()
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.s) {
                Button("Start setup", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(Spacing.l)
            .background(.bar)
        }
    }

    private func onboardingCard(symbol: String, title: LocalizedStringResource, body: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .cardSurface()
    }
}

/// A short in-app wizard for the three things a new user needs to know.
struct OnboardingWizardView: View {
    let skinType: SkinType
    var onFinish: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let steps: [WizardStep] = [
        WizardStep(
            symbol: "location.fill",
            title: "Choose where you are",
            body: "Let Bronzla use your location, or pick a city manually. The UV number on Today is only useful if the place is right."
        ),
        WizardStep(
            symbol: "timer.circle.fill",
            title: "Start the timer before you go out",
            body: "The timer uses your skin type and SPF to keep the session honest, then reminds you when to flip, reapply, or stop."
        ),
        WizardStep(
            symbol: "gearshape.fill",
            title: "Tune the details later",
            body: "Settings holds your skin type, profiles, alerts, and exports. You do not need to learn it all up front."
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack {
                Text("How to use Bronzla")
                    .font(.title.weight(.semibold))

                Spacer(minLength: 0)

                Text("\(step + 1)/\(steps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            TabView(selection: $step) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    wizardCard(step: item)
                        .tag(index)
                        .padding(.top, Spacing.s)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: Spacing.m) {
                Button("Back") {
                    withAnimation(.smooth) { step -= 1 }
                }
                .buttonStyle(.bordered)
                .opacity(step == 0 ? 0 : 1)
                .disabled(step == 0)

                Spacer(minLength: 0)

                if step < steps.count - 1 {
                    Button("Next") {
                        withAnimation(.smooth) { step += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") { finish() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)

            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Your skin type: Type \(skinType.numeral)")
                    .font(.headline)
                Text("You can change it later in Settings if needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .cardSurface()

            MedicalDisclaimer()
        }
        .padding(Spacing.l)
    }

    private func wizardCard(step: WizardStep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Image(systemName: step.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.tint)

            Text(step.title)
                .font(.title2.weight(.semibold))

            Text(step.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
        .padding(Spacing.l)
        .cardSurface()
    }

    private func finish() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

private struct WizardStep {
    let symbol: String
    let title: LocalizedStringResource
    let body: LocalizedStringResource
}
