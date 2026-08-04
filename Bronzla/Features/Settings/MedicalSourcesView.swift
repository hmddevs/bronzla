import SwiftUI

/// Every published source behind the app's UV, skin type, sunscreen, vitamin D and aftercare
/// guidance, grouped by category, with a tappable link to each one.
///
/// Reachable in one tap from `MedicalDisclaimer` on every guidance screen, and from Settings >
/// About, so citations stay easy to find regardless of which screen a reviewer or user starts
/// from.
struct MedicalSourcesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("""
                These are the published sources behind the times, thresholds and advice shown \
                in Bronzla. Where a number in the app traces back to a paper or an official \
                guideline, it is listed here.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)

                ForEach(MedicalSource.Category.allCases, id: \.self) { category in
                    let sources = MedicalSource.all.filter { $0.category == category }
                    if !sources.isEmpty {
                        section(for: category, sources: sources)
                    }
                }

                Text("Bronzla is not a substitute for an examination by a dermatologist.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.l)
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(for category: MedicalSource.Category, sources: [MedicalSource]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(category.title)
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.l) {
                ForEach(sources) { source in
                    sourceRow(source)
                }
            }
            .cardSurface()
        }
    }

    private func sourceRow(_ source: MedicalSource) -> some View {
        Link(destination: source.url) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)

                Text(citation(for: source))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(source.backs)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
            }
        }
        .tint(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the source in your browser"))
    }

    private func citation(for source: MedicalSource) -> String {
        var parts = [source.authors, source.publicationDetail]
        if let year = source.year {
            parts.append(String(year))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        MedicalSourcesView()
    }
}
