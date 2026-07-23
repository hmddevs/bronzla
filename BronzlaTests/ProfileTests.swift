import Foundation
import Testing
@testable import Bronzla

/// Pure profile-selection and migration logic, tested with plain, unsaved `UserProfile`
/// instances so no `ModelContainer` is needed. Every `UserProfile()` still gets a distinct
/// `persistentModelID` even outside a container, which is what these tests rely on.
@Suite("Active profile resolution")
struct ProfileTests {

    @Test("Resolving with no stored identifier falls back to the first profile")
    func resolveFallsBackToFirstWhenNothingStored() {
        let a = UserProfile(name: "A")
        let b = UserProfile(name: "B")
        let resolved = ActiveProfileResolution.resolve(profiles: [a, b], storedIdentifier: nil)
        #expect(resolved === a)
    }

    @Test("Resolving with a stored identifier that matches returns that profile")
    func resolveHonoursStoredIdentifier() {
        let a = UserProfile(name: "A")
        let b = UserProfile(name: "B")
        let resolved = ActiveProfileResolution.resolve(profiles: [a, b], storedIdentifier: b.persistentModelID)
        #expect(resolved === b)
    }

    @Test("Resolving with a stored identifier for a deleted profile falls back to the first")
    func resolveFallsBackWhenStoredProfileIsGone() {
        let a = UserProfile(name: "A")
        let b = UserProfile(name: "B")
        let deleted = UserProfile(name: "Deleted")
        let resolved = ActiveProfileResolution.resolve(profiles: [a, b], storedIdentifier: deleted.persistentModelID)
        #expect(resolved === a)
    }

    @Test("Resolving an empty list returns nil rather than crashing")
    func resolveHandlesEmptyList() {
        #expect(ActiveProfileResolution.resolve(profiles: [], storedIdentifier: nil) == nil)
    }

    @Test("Applying active marks exactly one profile active, never zero or two")
    func applyActiveIsExclusive() {
        let a = UserProfile(name: "A", isActive: true)
        let b = UserProfile(name: "B")
        let c = UserProfile(name: "C")
        ActiveProfileResolution.applyActive(b, to: [a, b, c])
        #expect(a.isActive == false)
        #expect(b.isActive == true)
        #expect(c.isActive == false)
    }

    @Test("The last remaining profile cannot be deleted")
    func lastProfileCannotBeDeleted() {
        let only = UserProfile(name: "Only")
        #expect(ActiveProfileResolution.canDelete(only, from: [only]) == false)
    }

    @Test("A profile can be deleted when siblings remain")
    func profileCanBeDeletedWhenSiblingsExist() {
        let a = UserProfile(name: "A")
        let b = UserProfile(name: "B")
        #expect(ActiveProfileResolution.canDelete(a, from: [a, b]) == true)
    }

    @Test("Deleting a profile that was not active leaves the active profile unchanged")
    func deletingInactiveProfileDoesNotSuggestAReplacement() {
        let active = UserProfile(name: "Active", isActive: true)
        let other = UserProfile(name: "Other")
        let replacement = ActiveProfileResolution.profileToActivateAfterDeleting(other, from: [active, other])
        #expect(replacement == nil)
    }

    @Test("Deleting the active profile suggests one of the remaining siblings")
    func deletingActiveProfileSuggestsASibling() {
        let active = UserProfile(name: "Active", isActive: true)
        let other = UserProfile(name: "Other")
        let replacement = ActiveProfileResolution.profileToActivateAfterDeleting(active, from: [active, other])
        #expect(replacement === other)
    }

    @Test("Migration names and activates a single unnamed legacy profile")
    func migrationFixesUpALegacyProfile() {
        let legacy = UserProfile()
        #expect(legacy.name.isEmpty)
        #expect(legacy.isActive == false)

        ActiveProfileResolution.migrateLegacyProfileIfNeeded([legacy])

        #expect(legacy.name == String(localized: "Me"))
        #expect(legacy.isActive == true)
    }

    @Test("Migration leaves an already-named, already-active profile untouched")
    func migrationIsIdempotent() {
        let profile = UserProfile(name: "Ayşe", isActive: true)
        ActiveProfileResolution.migrateLegacyProfileIfNeeded([profile])
        #expect(profile.name == "Ayşe")
        #expect(profile.isActive == true)
    }

    @Test("Migration does nothing once a second profile exists")
    func migrationSkipsWhenMultipleProfilesExist() {
        let a = UserProfile()
        let b = UserProfile(name: "B")
        ActiveProfileResolution.migrateLegacyProfileIfNeeded([a, b])
        #expect(a.name.isEmpty)
        #expect(a.isActive == false)
    }
}
