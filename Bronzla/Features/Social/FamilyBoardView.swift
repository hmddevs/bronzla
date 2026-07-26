import SwiftData
import SwiftUI

/// "Family Ranking": ranks family profiles by `BronzScore.total`, the discipline score, never
/// by hours or darkness. Scoped locally, from sessions already on this device, attributed to
/// whichever profile logged them.
///
/// The "Global" segment is a separate, optional leaderboard across every signed-in Bronzla
/// user. Signing in gates only that segment; the family ranking above works fully offline,
/// exactly as before.
struct FamilyBoardView: View {
    private enum Scope: String, CaseIterable {
        case family, global

        var title: LocalizedStringResource {
            switch self {
            case .family: "Family"
            case .global: "Global"
            }
        }
    }

    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query private var sessions: [TanSession]
    @Environment(\.leaderboardService) private var leaderboardService
    @State private var scope: Scope = .family
    @State private var globalBoard = GlobalBoardModel()

    private var ranked: [(profile: UserProfile, score: BronzScore)] {
        profiles
            .map { profile in
                let owned = sessions.filter { $0.profile?.persistentModelID == profile.persistentModelID }
                return (profile, BronzScore.make(from: owned))
            }
            .sorted { $0.score.total > $1.score.total }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ranking", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.m)

            Group {
                switch scope {
                case .family: familyList
                case .global: globalContent
                }
            }
        }
        .navigationTitle("Ranking")
        .task {
            globalBoard.restoreSession(using: leaderboardService)
            if globalBoard.session != nil { globalBoard.load(using: leaderboardService) }
        }
    }

    private var familyList: some View {
        List {
            if ranked.isEmpty {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "trophy",
                    description: Text("The ranking appears here as family members record sessions.")
                )
            } else {
                ForEach(Array(ranked.enumerated()), id: \.element.profile.persistentModelID) { index, entry in
                    row(rank: index + 1, profile: entry.profile, score: entry.score)
                }
            }
        }
        .accessibilityIdentifier("social.familyBoard")
    }

    @ViewBuilder
    private var globalContent: some View {
        if globalBoard.session == nil {
            AppleSignInView { session in
                globalBoard.signedIn(session, using: leaderboardService)
            }
        } else {
            switch globalBoard.phase {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Could not load leaderboard", systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { globalBoard.load(using: leaderboardService) }
                }
            case .loaded(let entries):
                List {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "No entries yet",
                            systemImage: "trophy",
                            description: Text("The global leaderboard appears here once people finish sessions.")
                        )
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            globalRow(rank: index + 1, entry: entry)
                        }
                    }
                }
                .accessibilityIdentifier("social.globalBoard")
            }
        }
    }

    private func globalRow(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack(spacing: Spacing.m) {
            Text("\(rank)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(entry.displayName)
                .font(.body)

            Spacer(minLength: 0)

            Text(Int(entry.score).formatted())
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func row(rank: Int, profile: UserProfile, score: BronzScore) -> some View {
        HStack(spacing: Spacing.m) {
            Text("\(rank)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Circle()
                .fill(profile.accentColour)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(profile.name.isEmpty ? String(localized: "Unnamed") : profile.name)
                    .font(.body)
                Text(String(localized: score.title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(score.total)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        FamilyBoardView()
    }
    .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
