import SwiftUI

/// Countdown ring with the remaining time at its centre.
///
/// Takes `progress` and `remaining` as plain values rather than reading a clock. The caller's
/// `TimelineView` decides when to redraw, so this view has no notion of time passing and can
/// be previewed at any point in a session.
struct TimerRing: View {
    let progress: Double
    let remaining: TimeInterval
    let isRunning: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 58

    private let lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: .init(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)

            VStack(spacing: Spacing.xs) {
                Text(Self.clock(remaining))
                    .font(.system(size: timeFontSize, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))

                Text(isRunning ? "remaining" : "paused")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 280)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time remaining"))
        .accessibilityValue(Text(Self.spoken(remaining)))
    }

    /// mm:ss below an hour, h:mm:ss above it. Rounds up, so the ring never shows 0:00 while
    /// the session is still running.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Spoken by VoiceOver, so it must follow the device language rather than the source
    /// language. `.wide` gives "5 minutes 30 seconds" rather than an abbreviation a screen
    /// reader would have to spell out.
    static func spoken(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        var allowed: Set<Duration.UnitsFormatStyle.Unit> = [.seconds]
        if total >= 60 { allowed.insert(.minutes) }
        return Duration.seconds(total).formatted(.units(allowed: allowed, width: .wide))
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        TimerRing(progress: 0.35, remaining: 1_140, isRunning: true, tint: Palette.colour(for: .high))
        TimerRing(progress: 0.8, remaining: 240, isRunning: false, tint: Palette.colour(for: .veryHigh))
    }
    .padding()
}
