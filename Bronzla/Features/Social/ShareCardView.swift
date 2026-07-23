import SwiftUI

/// The 9:16 image that goes to a Story.
///
/// Rendered at a fixed 1080 x 1920 logical size rather than adapting to the device, because it
/// is an export target, not a screen. `ImageRenderer` scales it up; nothing here reflows.
///
/// Editorial rule for everything on this card: it states what the person *did not* do as much
/// as what they did. "Zero burns" is the headline, not hours accumulated. A card boasting six
/// hours in the sun would be the app advertising the behaviour it exists to moderate.
struct ShareCardView: View {
    enum Content: Equatable {
        /// A single finished session.
        case session(place: String, duration: Duration, peakUV: Double, spf: Int, burnRisk: Double)
        /// A whole season.
        case season(score: BronzScore, hours: Double, places: Int)
        /// Tan progression, with photos supplied by the caller.
        case progress(days: Int, sessions: Int)
    }

    let content: Content
    var profileName: String = ""
    /// Supplied for `.progress`, drawn side by side.
    var beforeImage: UIImage?
    var afterImage: UIImage?

    static let size = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                body(for: content)
                Spacer(minLength: 0)
                wordmark
            }
            .padding(72)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        // Cards are an export, not UI. Locking to dark keeps them legible on every Story
        // background and consistent whatever theme the user runs.
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Chrome

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.71, blue: 0.33),
                Color(red: 0.95, green: 0.44, blue: 0.29),
                Color(red: 0.42, green: 0.16, blue: 0.30),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(Color.black.opacity(0.12))
    }

    private var header: some View {
        HStack {
            if !profileName.isEmpty {
                Text(profileName.uppercased())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(4)
            }
            Spacer(minLength: 0)
            Text(Date.now, format: .dateTime.day().month(.abbreviated))
                .font(.system(size: 34, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    /// Always present, never removable. On a paid app with no ad budget the share card is the
    /// cheapest acquisition channel there is, and a card nobody can trace back is wasted reach.
    /// It is restrained rather than absent: a wordmark, not a watermark.
    private var wordmark: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 34))
            Text("Bronzla")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
            Text("Safe sunbathing")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Bodies

    @ViewBuilder
    private func body(for content: Content) -> some View {
        switch content {
        case let .session(place, duration, peakUV, spf, burnRisk):
            sessionBody(place: place, duration: duration, peakUV: peakUV, spf: spf, burnRisk: burnRisk)
        case let .season(score, hours, places):
            seasonBody(score: score, hours: hours, places: places)
        case let .progress(days, sessions):
            progressBody(days: days, sessions: sessions)
        }
    }

    private func sessionBody(place: String, duration: Duration, peakUV: Double, spf: Int, burnRisk: Double) -> some View {
        VStack(alignment: .leading, spacing: 40) {
            if burnRisk < 1 {
                pill(String(localized: "Zero burns").uppercased(), symbol: "checkmark.seal.fill")
            }

            Text(place)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            HStack(spacing: 56) {
                stat(Self.duration(duration), label: "duration")
                stat("UV \(Int(peakUV.rounded()))", label: "peak")
                stat(spf > 1 ? "SPF \(spf)" : String(localized: "None"), label: "protection")
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func seasonBody(score: BronzScore, hours: Double, places: Int) -> some View {
        VStack(alignment: .leading, spacing: 36) {
            pill(String(localized: score.title).uppercased(), symbol: "trophy.fill")

            Text("\(score.total)")
                .font(.system(size: 200, weight: .light, design: .rounded))
                .minimumScaleFactor(0.5)

            Text("Tan Score")
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .opacity(0.85)

            HStack(spacing: 48) {
                stat("\(score.sessionCount)", label: "sessions")
                stat("\(score.longestStreak)", label: "longest streak")
                stat("\(places)", label: "beaches")
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressBody(days: Int, sessions: Int) -> some View {
        VStack(spacing: 40) {
            HStack(spacing: 24) {
                photo(beforeImage, caption: "Day 1")
                photo(afterImage, caption: "Day \(days)")
            }

            HStack(spacing: 48) {
                stat("\(days)", label: "days")
                stat("\(sessions)", label: "sessions")
            }
            .foregroundStyle(.white)
        }
    }

    // MARK: - Pieces

    private func photo(_ image: UIImage?, caption: LocalizedStringResource) -> some View {
        VStack(spacing: 16) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.15)
                }
            }
            .frame(width: 420, height: 560)
            .clipShape(.rect(cornerRadius: 32))

            Text(caption)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func stat(_ value: String, label: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 60, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
    }

    private func pill(_ text: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
            Text(text)
                .tracking(3)
        }
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(.white.opacity(0.2), in: .capsule)
    }

    static func duration(_ duration: Duration) -> String {
        let minutes = max(Int((duration.seconds / 60).rounded()), 0)
        // Locale-aware: gives "25 min" / "1 hr 25 min" in English and "25 dk" / "1 sa 25 dk"
        // in Turkish, instead of hardcoding one language's abbreviations into both.
        var allowed: Set<Duration.UnitsFormatStyle.Unit> = []
        if minutes >= 60 { allowed.insert(.hours) }
        if minutes % 60 != 0 || minutes < 60 { allowed.insert(.minutes) }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }
}
