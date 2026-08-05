import ActivityKit
import SwiftUI
import WidgetKit

/// Lock screen and Dynamic Island presentation for a running session.
///
/// This is the feature's real home. Someone lying on a beach with the phone face down does not
/// unlock it to check a timer; they glance at the lock screen when it lights up. Everything
/// here is driven by `Text(timerInterval:)`, which the system counts down without waking the
/// app, so the display stays correct even while the app is suspended or terminated.
struct TanSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TanSessionAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.placeName, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("UV \(Int(context.attributes.uvIndexAtStart.rounded()))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    countdown(context, font: .system(size: 34, weight: .light, design: .rounded))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        statusLine(context)
                            .font(.caption)
                        weatherAttribution
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "sun.max.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context, font: .caption2.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }

    // MARK: - Lock screen

    private func lockScreen(_ context: ActivityViewContext<TanSessionAttributes>) -> some View {
        // The card carries its own fixed dark tint (below) regardless of the device's system
        // appearance, but `.primary`/`.secondary` still resolve against system appearance, not
        // the tint. Without a forced white base, the countdown and UV label rendered black on
        // Light Mode devices: unreadable against this background. Setting white here becomes
        // the hierarchy's primary, so descendants using `.secondary` still dim correctly against
        // white rather than against whatever the system appearance would have chosen.
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sunbathing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                countdown(context, font: .system(size: 40, weight: .light, design: .rounded))

                statusLine(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Label("UV \(Int(context.attributes.uvIndexAtStart.rounded()))", systemImage: "sun.max.fill")
                    .font(.subheadline.weight(.medium))
                Text("Type \(context.attributes.skinTypeNumeral) · SPF \(context.attributes.spf)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.attributes.placeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    /// A paused session shows a frozen figure; a running one hands the countdown to the system.
    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<TanSessionAttributes>, font: Font) -> some View {
        if context.state.isPaused {
            Text(Self.frozen(context.state.pausedElapsed))
                .font(font)
                .monospacedDigit()
        } else {
            Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
                .font(font)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func statusLine(_ context: ActivityViewContext<TanSessionAttributes>) -> some View {
        if context.state.isPaused {
            Label("Paused", systemImage: "pause.fill")
        } else if context.state.isAwaitingFlip {
            Label("Time to turn over", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.orange)
        } else if let flipAt = context.state.flipAt {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Flip in ")
                Text(timerInterval: Date.now...flipAt, countsDown: true)
                    .monospacedDigit()
            }
        } else {
            Label("Final stretch", systemImage: "checkmark")
        }
    }

    static func frozen(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// WeatherKit trademark text mark, shown only in the Dynamic Island's expanded region.
    /// Compact and minimal presentations have no room for it; the lock screen banner is left
    /// as decided, since the app already carries the full linked attribution. `.verbatim`
    /// because a trademark is not translated between locales.
    private var weatherAttribution: some View {
        Text(verbatim: "Weather")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
