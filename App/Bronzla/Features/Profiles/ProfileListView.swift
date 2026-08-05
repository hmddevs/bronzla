import SwiftData
import SwiftUI

/// Every family profile: switch, add, edit, delete.
///
/// Reached from Settings. Not a tab of its own: switching profile is an occasional action, not
/// a daily one, so it does not deserve permanent chrome.
struct ProfileListView: View {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var activeStore = ActiveProfileStore()

    @State private var isShowingQuiz = false
    @State private var editingProfile: UserProfile?
    @State private var editingProfileIsNew = false

    var body: some View {
        List {
            ForEach(profiles) { profile in
                row(for: profile)
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { isShowingQuiz = true }
            }
        }
        // Idempotent, so revisiting this screen after the fix ships is a no-op; only a profile
        // saved before multi-profile support ever needs it.
        .task { ActiveProfileResolution.migrateLegacyProfileIfNeeded(profiles) }
        .sheet(isPresented: $isShowingQuiz) {
            SkinTypeQuizView { skinType in
                addProfile(skinType: skinType)
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile, isNew: editingProfileIsNew)
        }
    }

    // MARK: - Rows

    private func row(for profile: UserProfile) -> some View {
        let isActive = activeStore.profile(in: profiles)?.persistentModelID == profile.persistentModelID

        return Button {
            activeStore.setActive(profile, in: profiles)
        } label: {
            HStack(spacing: Spacing.m) {
                Circle()
                    .fill(profile.accentColour)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(profile.name.isEmpty ? String(localized: "Unnamed") : profile.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Type \(profile.skinType.numeral) · SPF \(profile.defaultSPF)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if ActiveProfileResolution.canDelete(profile, from: profiles) {
                Button("Delete", role: .destructive) { delete(profile) }
            }
            Button("Edit") { editingProfileIsNew = false; editingProfile = profile }
                .tint(.blue)
        }
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: - Actions

    private func addProfile(skinType: SkinType) {
        let created = UserProfile(skinType: skinType, hasCompletedOnboarding: true)
        modelContext.insert(created)
        editingProfileIsNew = true
        editingProfile = created
    }

    /// Deletion of the last profile is refused rather than silently ignored, since `RootView`'s
    /// onboarding gate and every screen reading `profiles.first` assume one always exists.
    private func delete(_ profile: UserProfile) {
        guard ActiveProfileResolution.canDelete(profile, from: profiles) else { return }

        let replacement = ActiveProfileResolution.profileToActivateAfterDeleting(profile, from: profiles)
        modelContext.delete(profile)

        if let replacement {
            let remaining = profiles.filter { $0.persistentModelID != profile.persistentModelID }
            activeStore.setActive(replacement, in: remaining)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileListView()
    }
    .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
