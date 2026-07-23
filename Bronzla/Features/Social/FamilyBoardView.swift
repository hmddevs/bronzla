import SwiftData
import SwiftUI

/// "Family Ranking": ranks family profiles by `BronzScore.total`, the discipline score, never
/// by hours or darkness. No accounts, no backend: every number here comes from sessions already
/// on this device, attributed to whichever profile logged them.
struct FamilyBoardView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query private var sessions: [TanSession]

    private var ranked: [(profile: UserProfile, score: BronzScore)] {
        profiles
            .map { profile in
                let owned = sessions.filter { $0.profile?.persistentModelID == profile.persistentModelID }
                return (profile, BronzScore.make(from: owned))
            }
            .sorted { $0.score.total > $1.score.total }
    }

    var body: some View {
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
        .navigationTitle("Family Ranking")
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
