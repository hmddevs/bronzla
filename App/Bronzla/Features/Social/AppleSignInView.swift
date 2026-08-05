import AuthenticationServices
import SwiftUI

/// Sign in with Apple, used only to gate the global leaderboard tab. Requests `.fullName`
/// once, purely to prefill an editable display name; never requests `.email`, since the
/// server never needs one and Bronzla's privacy posture is to ask for the least it can.
///
/// Apple's own name grant is never sent to the server as-is: it only ever pre-fills
/// `DisplayNameEntryView`, and the person must confirm or edit it there before anything is
/// sent. This is what keeps this screen's "Never your real name" promise true, since Apple's
/// `fullName` is, by default, the person's real name.
struct AppleSignInView: View {
    var onSignedIn: (LeaderboardSession) -> Void

    @Environment(\.leaderboardService) private var leaderboardService
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var pendingSignIn: PendingSignIn?

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Sign in to see the global leaderboard")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Only your display name and Tan Score are shared. Never your real name, email or location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SignInWithAppleButton(.signIn, onRequest: configure, onCompletion: handle)
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .disabled(isSigningIn)
                .accessibilityIdentifier("social.appleSignIn")

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.l)
        .sheet(item: $pendingSignIn) { pending in
            DisplayNameEntryView(
                prefillName: pending.prefillName,
                isSubmitting: isSigningIn
            ) { chosenName in
                completeSignIn(identityToken: pending.identityToken, displayName: chosenName)
            } onCancel: {
                pendingSignIn = nil
            }
        }
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName]
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // `ASAuthorizationError.canceled` is the user backing out, not a failure worth
            // surfacing as an error.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = String(localized: "Apple did not return a usable sign-in token.")
                return
            }

            // Apple only grants `fullName` on the very first authorisation per app, so this is
            // `nil` on a second device or after a reinstall; `DisplayNameEntryView` copes with
            // an empty prefill by simply starting blank. Given name only, never the family name:
            // a surname is even more identifying than a first name, and this is a convenience
            // prefill, not something ever sent unseen.
            errorMessage = nil
            pendingSignIn = PendingSignIn(
                identityToken: identityToken,
                prefillName: credential.fullName?.givenName ?? ""
            )
        }
    }

    private func completeSignIn(identityToken: String, displayName: String) {
        Task {
            isSigningIn = true
            defer { isSigningIn = false }
            do {
                let session = try await leaderboardService.signIn(
                    identityToken: identityToken,
                    displayName: displayName
                )
                pendingSignIn = nil
                onSignedIn(session)
            } catch {
                pendingSignIn = nil
                errorMessage = (error as? LeaderboardError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private struct PendingSignIn: Identifiable {
        let id = UUID()
        let identityToken: String
        let prefillName: String
    }
}

/// Decides whether a proposed display name is acceptable to send: non-empty once whitespace at
/// either end is discarded. Kept as a free function so the validation rule is testable in
/// isolation from the view that uses it.
enum DisplayNameValidation {
    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isAcceptable(_ name: String) -> Bool {
        !trimmed(name).isEmpty
    }
}

/// The required confirmation step between an Apple sign-in and the actual leaderboard sign-in
/// call. Nothing is sent to the server until the person has seen and accepted (or replaced)
/// whatever name is shown here.
private struct DisplayNameEntryView: View {
    let prefillName: String
    let isSubmitting: Bool
    var onContinue: (String) -> Void
    var onCancel: () -> Void

    @State private var displayName: String
    @Environment(\.dismiss) private var dismiss

    init(prefillName: String, isSubmitting: Bool, onContinue: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.prefillName = prefillName
        self.isSubmitting = isSubmitting
        self.onContinue = onContinue
        self.onCancel = onCancel
        _displayName = State(initialValue: prefillName)
    }

    private var isAcceptable: Bool {
        DisplayNameValidation.isAcceptable(displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Choose a display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("social.displayNameField")
                } header: {
                    Text("Display name")
                } footer: {
                    Text("This is what other people see on the global leaderboard, alongside your Tan Score. Choose something that isn't your real name.")
                }
            }
            .navigationTitle("Choose a display name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onContinue(DisplayNameValidation.trimmed(displayName))
                    }
                    .disabled(!isAcceptable || isSubmitting)
                    .accessibilityIdentifier("social.displayNameContinue")
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }
}

#Preview {
    AppleSignInView { _ in }
        .environment(\.leaderboardService, SampleLeaderboardProvider())
}
