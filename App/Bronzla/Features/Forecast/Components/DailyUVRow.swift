import SwiftUI

/// One day in the ten-day outlook: weekday, condition, temperature range and the peak UV that
/// actually drives whether it is a beach day.
struct DailyUVRow: View {
    let day: DailyUV

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(day.date, format: .dateTime.weekday(.wide))
                .font(.subheadline.weight(.medium))
                .frame(width: 88, alignment: .leading)

            Image(systemName: day.conditionSymbol)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)

            Spacer(minLength: Spacing.s)

            Text(day.highTemperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()

            Text(day.lowTemperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(Int(day.maxUVIndex.rounded()).formatted())
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Palette.colour(forUVIndex: day.maxUVIndex), in: .capsule)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack {
        DailyUVRow(day: UVReport.preview(peakUVIndex: 9).daily.first ?? DailyUV(
            date: .now,
            maxUVIndex: 9,
            highTemperature: Measurement(value: 32, unit: .celsius),
            lowTemperature: Measurement(value: 22, unit: .celsius),
            conditionSymbol: "sun.max.fill",
            sunrise: nil,
            sunset: nil
        ))
    }
    .padding()
}
