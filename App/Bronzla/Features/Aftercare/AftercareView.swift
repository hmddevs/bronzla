import SwiftUI

/// "Bakım": what to do about the skin after the fact, keyed off `burnRisk` alone so it works
/// equally well pinned to a finished session and opened standalone from a tab or settings link.
struct AftercareView: View {
    let burnRisk: Double

    private var advice: AftercareAdvice.Advice { AftercareAdvice.advice(forBurnRisk: burnRisk) }
    private var accent: Color { Palette.colour(for: advice.severity.uvCategory) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                if let prominentNotice = advice.prominentNotice {
                    doctorNotice(prominentNotice)
                }

                stepsCard
                cautionCard

                MedicalDisclaimer()
            }
            .padding(Spacing.l)
        }
        .navigationTitle("Care advice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(advice.severity.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            Text(advice.title)
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Set apart from the step list on purpose: a doctor referral read as list item four of six
    /// is a doctor referral nobody notices.
    private func doctorNotice(_ notice: LocalizedStringResource) -> some View {
        Label {
            Text(notice)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: "cross.case.fill")
        }
        .foregroundStyle(.white)
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent, in: .rect(cornerRadius: Spacing.cardRadius))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("What to do", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(advice.steps.enumerated()), id: \.offset) { _, step in
                Text(step)
                    .font(.subheadline)
            }
        }
        .cardSurface()
    }

    private var cautionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("What not to do", systemImage: "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(advice.doNotDo.enumerated()), id: \.offset) { _, caution in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(caution.action)
                        .font(.subheadline.weight(.medium))
                    Text(caution.reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardSurface()
    }
}

#Preview("Rutin") {
    NavigationStack { AftercareView(burnRisk: 0.2) }
}

#Preview("Dikkatli") {
    NavigationStack { AftercareView(burnRisk: 0.7) }
}

#Preview("Mild burn") {
    NavigationStack { AftercareView(burnRisk: 1.2) }
}

#Preview("Severe burn") {
    NavigationStack { AftercareView(burnRisk: 1.8) }
}
