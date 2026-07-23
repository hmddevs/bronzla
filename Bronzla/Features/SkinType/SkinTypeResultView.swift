import SwiftUI

/// The quiz outcome, framed as something actionable rather than a label.
///
/// The concrete burn time at UV 8 does the persuading: "Tip III" means nothing to most people,
/// "25 dakikada yanarsınız" means a great deal.
struct SkinTypeResultView: View {
    let skinType: SkinType
    var onConfirm: () -> Void
    var onRetake: () -> Void

    /// A representative Turkish summer noon, used purely to make the result tangible.
    private let referenceUVIndex: Double = 8

    private var burnTime: Duration? {
        ExposureCalculator.timeToBurn(uvIndex: referenceUVIndex, skinType: skinType)
    }

    private var protectedBurnTime: Duration? {
        ExposureCalculator.timeToBurn(uvIndex: referenceUVIndex, skinType: skinType, spf: skinType.recommendedSPF)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                badge

                VStack(spacing: Spacing.s) {
                    Text(skinType.title)
                        .font(.title.weight(.semibold))
                    Text(skinType.summary)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(skinType.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .cardSurface()

                comparison

                MedicalDisclaimer()
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) { actions }
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(Palette.backgroundWash(forUVIndex: referenceUVIndex))
                .frame(width: 132, height: 132)

            VStack(spacing: 0) {
                Text("TYPE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text(skinType.numeral)
                    .font(.system(size: 56, weight: .light, design: .rounded))
            }
        }
        .padding(.top, Spacing.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Cilt tipi \(skinType.numeral), \(String(localized: skinType.title))"))
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("At UV 8, a typical summer midday")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let burnTime, let protectedBurnTime {
                row(
                    symbol: "sun.max.trianglebadge.exclamationmark.fill",
                    tint: Palette.colour(for: .veryHigh),
                    title: "Unprotected",
                    value: SafeExposureCard.format(burnTime)
                )

                Divider()

                row(
                    symbol: "shield.lefthalf.filled",
                    tint: Palette.colour(for: .low),
                    title: "SPF \(skinType.recommendedSPF.formatted()) ile",
                    value: SafeExposureCard.format(protectedBurnTime)
                )
            }
        }
        .cardSurface()
    }

    private func row(symbol: String, tint: Color, title: LocalizedStringResource, value: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(title)
                .font(.body)

            Spacer(minLength: Spacing.s)

            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button(action: onConfirm) {
                Text("This is my skin type")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Retake the test", action: onRetake)
                .font(.subheadline)
        }
        .padding(Spacing.l)
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        SkinTypeResultView(skinType: .iv, onConfirm: {}, onRetake: {})
    }
}
