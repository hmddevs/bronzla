import SwiftUI

/// The short-form medical disclaimer, shown on every screen that gives exposure guidance.
///
/// Apple rejected v1.0 under guideline 1.4.1 for medical information without citations that
/// were "easy for the user to find". A caveat buried in Settings did not satisfy that: this
/// view is itself the tappable link, so the citations behind whatever guidance is on screen are
/// always one tap away, not one navigation hunt away. Moved out of `DashboardView` once it
/// became an interactive, cross-feature component rather than a single screen's private detail.
struct MedicalDisclaimer: View {
    @State private var isShowingSources = false

    var body: some View {
        Button {
            isShowingSources = true
        } label: {
            (
                Text("This app does not give medical advice. Times are based on average values and vary from person to person. See a dermatologist about any concerns with your skin. ")
                    .foregroundStyle(.secondary)
                + Text("Sources")
                    .foregroundStyle(.tint)
                    .underline()
            )
            .font(.caption2)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.s)
        .accessibilityLabel(Text("Medical disclaimer. This app does not give medical advice. Times are based on average values and vary from person to person. See a dermatologist about any concerns with your skin."))
        .accessibilityHint(Text("Shows the published sources behind this guidance"))
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isShowingSources) {
            NavigationStack {
                MedicalSourcesView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingSources = false }
                        }
                    }
            }
        }
    }
}

#Preview {
    MedicalDisclaimer()
        .padding()
}
