import SwiftUI

/// The hero reading: a 270-degree arc sweeping the WHO colour scale, with the index at its
/// centre.
///
/// The arc is drawn once as a full gradient and revealed by trimming, rather than as a
/// gradient sized to the current value. The colours therefore stay anchored to the scale, so
/// UV 4 sits at the same point on the arc every time.
struct UVGauge: View {
    let uvIndex: Double
    /// Nil while loading, which suppresses the reveal animation until there is a real value.
    var isLoading: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var indexFontSize: CGFloat = 76

    private let scaleMaximum: Double = 12
    private let sweep: Double = 0.75
    private let lineWidth: CGFloat = 18

    private var progress: Double { min(max(uvIndex, 0), scaleMaximum) / scaleMaximum }
    private var category: UVCategory { UVCategory(uvIndex: uvIndex) }

    var body: some View {
        ZStack {
            track
            fill
            readout
        }
        .frame(maxWidth: 280)
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: uvIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("UV index"))
        .accessibilityValue(Text("\(Int(uvIndex.rounded())), \(String(localized: category.title))"))
    }

    private var track: some View {
        Circle()
            .trim(from: 0, to: sweep)
            .stroke(Palette.hairline.opacity(0.25), style: .init(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(135))
    }

    private var fill: some View {
        Circle()
            .trim(from: 0, to: sweep * progress)
            .stroke(
                AngularGradient(gradient: Palette.uvScale, center: .center, angle: .degrees(135)),
                style: .init(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(135))
            .shadow(color: Palette.colour(forUVIndex: uvIndex).opacity(0.35), radius: 12)
    }

    private var readout: some View {
        VStack(spacing: Spacing.xs) {
            Text("UV")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text(isLoading ? "--" : Int(uvIndex.rounded()).formatted())
                .font(.system(size: indexFontSize, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Palette.colour(forUVIndex: uvIndex))

            Text(category.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .opacity(isLoading ? 0.4 : 1)
    }
}

#Preview("Scale") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            ForEach([1.0, 4.0, 7.0, 9.0, 11.0], id: \.self) { value in
                UVGauge(uvIndex: value)
            }
        }
        .padding()
    }
}
