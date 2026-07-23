import SwiftUI

/// Translates the raw index into the only number most people actually want: how long they
/// can stay out.
struct SafeExposureCard: View {
    let uvIndex: Double
    let skinType: SkinType
    let spf: Int

    private var recommended: Duration? {
        ExposureCalculator.recommendedSession(uvIndex: uvIndex, skinType: skinType, spf: spf)
    }

    private var burn: Duration? {
        ExposureCalculator.timeToBurn(uvIndex: uvIndex, skinType: skinType, spf: spf)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Safe time", systemImage: "clock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let recommended, let burn {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(Self.format(recommended))
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("Cilt tipi \(skinType.numeral) · SPF \(spf.formatted())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.colour(for: .veryHigh))
                    Text("Burning may begin after \(Self.format(burn)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("There is no burn risk right now. The sun will not tan you at this hour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    /// Rounds to the minute and formats in the device language: "1 hr 25 min" / "1 sa 25 dk".
    static func format(_ duration: Duration) -> String {
        let totalMinutes = max(Int((duration.seconds / 60).rounded()), 0)
        // Locale-aware: gives "25 min" / "1 hr 25 min" in English and "25 dk" / "1 sa 25 dk"
        // in Turkish, instead of hardcoding one language's abbreviations into both.
        var allowed: Set<Duration.UnitsFormatStyle.Unit> = []
        if totalMinutes >= 60 { allowed.insert(.hours) }
        if totalMinutes % 60 != 0 || totalMinutes < 60 { allowed.insert(.minutes) }
        return Duration.seconds(totalMinutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }
}

#Preview {
    VStack(spacing: Spacing.l) {
        SafeExposureCard(uvIndex: 9, skinType: .iii, spf: 30)
        SafeExposureCard(uvIndex: 9, skinType: .v, spf: 1)
        SafeExposureCard(uvIndex: 0, skinType: .iii, spf: 30)
    }
    .padding()
}
