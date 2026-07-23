import Charts
import SwiftUI

/// The next 24 hours as a coloured curve. The gradient is built from the same UV scale as the
/// gauge on "Today", so a glance at the shape tells you when to be careful without reading a
/// single number.
struct HourlyUVChart: View {
    let hours: [HourlyUV]
    let now: Date

    private var peak: HourlyUV? {
        hours.max { $0.uvIndex < $1.uvIndex }
    }

    private var gradient: LinearGradient {
        let colours = hours.isEmpty
            ? [Palette.colour(forUVIndex: 0)]
            : hours.map { Palette.colour(forUVIndex: $0.uvIndex) }
        return LinearGradient(colors: colours, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Chart {
            ForEach(hours) { hour in
                AreaMark(
                    x: .value("Hour", hour.date),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("UV", hour.uvIndex)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(gradient.opacity(0.35))

                LineMark(
                    x: .value("Hour", hour.date),
                    y: .value("UV", hour.uvIndex)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(gradient)
            }

            if let peak {
                PointMark(
                    x: .value("Hour", peak.date),
                    y: .value("UV", peak.uvIndex)
                )
                .foregroundStyle(Palette.colour(forUVIndex: peak.uvIndex))
                .annotation(position: .top) {
                    Text(Int(peak.uvIndex.rounded()).formatted())
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            RuleMark(x: .value("Now", now))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
        }
        .chartYScale(domain: 0...12)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hourly UV index chart")
    }
}

#Preview {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: .now)
    let hours = (0..<24).map { offset -> HourlyUV in
        let date = calendar.date(byAdding: .hour, value: offset, to: start) ?? start
        let hour = Double(offset)
        let uv = hour > 6 && hour < 20 ? 9 * pow(sin((hour - 6) / 14 * .pi), 2) : 0
        return HourlyUV(date: date, uvIndex: uv, temperature: Measurement(value: 30, unit: .celsius), isDaylight: uv > 0)
    }
    return HourlyUVChart(hours: hours, now: .now)
        .padding()
}
