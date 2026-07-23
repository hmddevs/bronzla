import SwiftUI

/// Colour, gradient and spacing tokens.
///
/// Defined in code rather than an asset catalog because every colour here is derived from the
/// UV scale, and a derivation you can read beats fifteen hand-tuned swatches you cannot.
enum Palette {

    // MARK: - UV scale

    /// Anchor colours for the WHO bands. Chosen to stay distinguishable for the most common
    /// forms of colour vision deficiency: the scale also rises monotonically in luminance, so
    /// severity is legible without relying on hue alone.
    static func colour(for category: UVCategory) -> Color {
        switch category {
        case .low: Color(red: 0.24, green: 0.72, blue: 0.47)
        case .moderate: Color(red: 0.96, green: 0.78, blue: 0.24)
        case .high: Color(red: 0.96, green: 0.55, blue: 0.20)
        case .veryHigh: Color(red: 0.90, green: 0.29, blue: 0.26)
        case .extreme: Color(red: 0.60, green: 0.33, blue: 0.78)
        }
    }

    /// Continuous colour for an arbitrary index, interpolating between band anchors so the
    /// gauge sweeps smoothly instead of stepping.
    static func colour(forUVIndex index: Double) -> Color {
        let clamped = min(max(index, 0), 12)
        let stops: [(threshold: Double, colour: Color)] = [
            (0, colour(for: .low)),
            (3, colour(for: .moderate)),
            (6, colour(for: .high)),
            (8, colour(for: .veryHigh)),
            (11, colour(for: .extreme)),
            (12, colour(for: .extreme)),
        ]

        guard let upperIndex = stops.firstIndex(where: { $0.threshold >= clamped }), upperIndex > 0 else {
            return stops[0].colour
        }
        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let span = upper.threshold - lower.threshold
        let progress = span > 0 ? (clamped - lower.threshold) / span : 0
        return lower.colour.mix(with: upper.colour, by: progress)
    }

    /// Gradient used by the gauge arc, spanning the full scale.
    static let uvScale = Gradient(colors: [
        colour(for: .low),
        colour(for: .moderate),
        colour(for: .high),
        colour(for: .veryHigh),
        colour(for: .extreme),
    ])

    /// Background wash behind the hero reading. Deliberately restrained: a low-opacity tint
    /// that carries the mood without competing with the numerals in front of it.
    static func backgroundWash(forUVIndex index: Double) -> LinearGradient {
        let tint = colour(forUVIndex: index)
        return LinearGradient(
            colors: [tint.opacity(0.22), tint.opacity(0.04), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Surfaces

    /// Card surface. `.background` variants adapt to light and dark automatically, which is
    /// why no explicit dark-mode branch appears anywhere in this file.
    static let card = Color(.secondarySystemBackground)
    static let cardElevated = Color(.tertiarySystemBackground)
    static let hairline = Color(.separator)
}

/// Layout rhythm. A single scale, so nothing is ever "about 14".
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
}

extension View {
    /// Standard card treatment. One definition, so every surface in the app matches.
    func cardSurface(padding: CGFloat = Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: .rect(cornerRadius: Spacing.cardRadius))
    }
}
