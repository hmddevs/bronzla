import SwiftData
import SwiftUI

/// Fixed accent palette for profiles. A closed set, not the system colour picker, keeps every
/// profile's colour visually consistent with the rest of the app's restrained palette.
enum ProfilePalette {
    static let swatches: [String] = [
        "#FF9500", "#FF375F", "#34C759", "#0A84FF", "#AF52DE", "#FFD60A",
    ]
}

extension Color {
    /// Parses "#RRGGBB". `nil` for anything malformed, so a corrupted stored value falls back
    /// safely instead of crashing.
    init?(hex: String) {
        var sanitised = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitised.hasPrefix("#") { sanitised.removeFirst() }
        guard sanitised.count == 6, let value = UInt32(sanitised, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension UserProfile {
    /// Resolved accent colour, falling back to the first palette swatch if `colourHex` is ever
    /// malformed. Should not happen via the editor, but a corrupt stored value must not crash
    /// a row.
    var accentColour: Color {
        Color(hex: colourHex) ?? Color(hex: ProfilePalette.swatches[0]) ?? .accentColor
    }
}

/// Name, accent colour, SPF default and exposed-skin fraction for one profile.
///
/// Skin type itself is set by `SkinTypeQuizView` before this screen appears for a new profile,
/// or from Settings' own quiz entry point for the existing one; this screen only owns the
/// fields that do not need a seven-question instrument.
struct ProfileEditorView: View {
    @Bindable var profile: UserProfile
    /// True while completing a profile just created by `ProfileListView`'s add flow. Changes
    /// only the toolbar wording; the model is inserted into the context either way.
    var isNew = false

    @Environment(\.dismiss) private var dismiss

    private var trimmedName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                colourSection
                protectionSection
            }
            .navigationTitle(isNew ? "Add profile" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") { dismiss() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Name", text: $profile.name)
                .textInputAutocapitalization(.words)
        } header: {
            Text("Name")
        } footer: {
            Text("This name is shown when you switch between profiles.")
        }
    }

    private var colourSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                ForEach(ProfilePalette.swatches, id: \.self) { hex in
                    swatch(hex)
                }
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Text("Colour")
        }
    }

    private func swatch(_ hex: String) -> some View {
        let isSelected = profile.colourHex == hex

        return Button {
            profile.colourHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? .accentColor)
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Choose colour"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var protectionSection: some View {
        Section {
            Picker("Default SPF", selection: $profile.defaultSPF) {
                ForEach([1, 15, 20, 30, 50], id: \.self) { spf in
                    Text(spf == 1 ? String(localized: "Unprotected") : "SPF \(spf.formatted())")
                        .tag(spf)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                LabeledContent("Exposed skin") {
                    Text(profile.exposedBodyFraction, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $profile.exposedBodyFraction, in: 0.1...0.9, step: 0.05)
            }
        } header: {
            Text("Protection")
        } footer: {
            Text("Swimwear is roughly 60%, shorts and a t-shirt roughly 25%. This figure only affects the vitamin D estimate.")
        }
    }
}

#Preview {
    ProfileEditorView(profile: UserProfile(name: "Me"))
}
