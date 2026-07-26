# Bronzla — project brain

## Current phase
Shipping to TestFlight, as of 2026-07-23, build 1.0 (10), VALID on App Store Connect. All five
tabs, social sharing, the family leaderboard and an Apple Watch app are built. All three targets
build clean in Release from wiped DerivedData, zero compiler warnings. 125 tests pass (118 unit,
7 UI). The store listing is filled in for both `en-US` and `tr`: name, subtitle, description,
keywords, promotional text, URLs, categories, age rating and review notes, all set via the API.

**Sign in with Apple plus a global leaderboard has been added (2026-07-26), iOS side only.**
`LeaderboardServiceProviding` (`Bronzla/Services/Leaderboard/`) mirrors `UVDataProviding`'s
shape: `LiveLeaderboardService` (plain `URLSession`, no networking library) is wired to a
placeholder base URL since the CDK backend in `infra/` is built and unit-tested but not yet
deployed; `SampleLeaderboardProvider` backs previews and unit tests. Session token lives in the
Keychain (`KeychainSessionStore`), never `UserDefaults` or SwiftData. Sign-in gates only the new
"Global" segment of `FamilyBoardView` (renamed conceptually to a family/global leaderboard
picker) and an account row in `SettingsView`; every other feature, including the family ranking,
still works fully offline. `TimerView` pushes the recomputed running `BronzScore.total` (not a
per-session delta) to the leaderboard after `TanTimerModel.finish()`, fire-and-forget, matching
the existing "never let a network hiccup interrupt the core flow" posture. `PrivacyDetailView`
and `PrivacyInfo.xcprivacy` were updated to disclose the optional, linked user-identifier
collection this introduces. Not yet done: pointing `LiveLeaderboardService` at a real deployed
URL, and the manual device-based Sign in with Apple + backend round-trip test from the plan.

**Post-review hardening of Sign in with Apple + leaderboard (2026-07-26).** An independent
security review of the above found the sign-in flow sent Apple's real `fullName` straight to the
server as the public display name, contradicting the screen's own "Never your real name" promise.
Fixed by inserting a required `DisplayNameEntryView` step (`Features/Social/AppleSignInView.swift`)
between the Apple callback and `signIn(identityToken:displayName:)`: prefills with
`credential.fullName?.givenName` only (never the family name, never the joined full name) when
Apple grants one, starts blank otherwise (Apple only grants `fullName` on the very first
authorisation per app; a reinstall or second device gets nothing), and disables "Continue" until
the trimmed field is non-empty. Validation is a standalone `DisplayNameValidation` enum
(`isAcceptable`/`trimmed`), unit-tested in isolation from the view. Three related hardening fixes
in the same pass: `KeychainSessionStore` now uses
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (was `AfterFirstUnlock`, which would restore a
session token onto a different device from an encrypted backup) and `save()` returns a
`@discardableResult Bool` with `Logger` calls on encode/write failure, rather than swallowing both
via `try?` and a discarded `OSStatus`; `LeaderboardEntry.id` is now a client-generated `UUID`
(excluded from `Codable` via a custom `CodingKeys`, so decoding server JSON that never sends an
`id` still works, the synthesised `init(from:)` just uses the stored property's default) instead
of the display name itself, fixing SwiftUI identity collisions when two people pick the same name;
`TimerView.pushScoreIfSignedIn()` has a defensive empty-display-name guard (logs and skips) even
though the new sign-in step should make an empty name unreachable in practice.

**A second, unrelated, uncommitted change was already in progress in the working tree before
this leaderboard work started**: `RootView.swift` now presents a new `OnboardingFlowView`
(`Bronzla/Features/Onboarding/`, untracked) instead of `SkinTypeQuizView` directly, and this
broke `BronzlaFlowUITests` before the leaderboard changes touched anything (confirmed via `git
diff` showing those files modified pre-session, and by running the UI suite, which fails on
`testQuizIsPresentedOnFirstLaunchAndCannotBeSkipped` even on a freshly erased simulator with no
leaderboard code in the picture). Unit tests (124/124, including the new `Leaderboard` suite and
a `BronzScore` Codable round-trip test) all pass; the UI suite failure is pre-existing and needs
its own fix, unrelated to Sign in with Apple.

**The Live Activity has been observed running, on build 7, via TestFlight feedback with a
screenshot.** It has a real bug (see below), which is itself proof it renders: MEMORY.md and
APPSTORE.md's older claims that it had never been observed are now outdated on this point,
though it has still never been seen running on physical hardware by this session directly.

**Three real defects surfaced by Umut's own TestFlight testing of build 7, fixed in build 10:**
the session summary's OK button was a dead end (`cancel()` reused from `finish()` could never
clear `lastCompleted` a second time — `dismissSummary()` fixes it); the Live Activity's countdown
and UV label rendered black-on-black in Light Mode (no explicit foreground against the card's
fixed dark tint — forced white at the container level); and `.percent` formatting showed
Turkish-style symbol placement ("%0") on an English-language, Turkish-region device, because
`Locale.current` splits Language (drives words) from Region (drives symbol placement) — added
`Locale.app`, derived from `Bundle.main.preferredLocalizations`, and chained it onto every
`.percent` site. A fourth reported item (attribution row centering) measured out to a 1px
difference on pixel inspection — not a bug, not touched. **`ActivityKit.Activity.request` is not
safely callable from a bare unit-test host** — it crashes the test process. Anything that
exercises `TanTimerModel.start()` needs a UI test driving the real app, not a unit test.

What is left is account-level and cannot be done from code: the Paid Applications Agreement
(banking and tax), a price tier, the privacy nutrition labels (portal-only, confirmed by 404),
and uploading the screenshot PNGs. See `APPSTORE.md`.

**Localisation: verify by rendering, never by counting.** Every count claimed here has been
wrong in a different way. "418 strings, 0 untranslated" was wrong because it grepped xliff for
`state="new"`, which does not flag a string with no target at all. "348 keys, complete" was
wrong because it counted the phone catalogue while the extensions had none. "Complete for all
three targets" was wrong because the watch catalogue held only the strings written inside
`BronzlaWatch/`. Each claim was checkable and each was checked the wrong way. The method that
has actually worked every time is to launch the thing in each locale and read the screen.

## Roadmap to v1.0 (complete)
1. ~~Architecture, project file, design tokens~~ done
2. ~~Domain maths (`ExposureCalculator`) plus unit tests~~ done
3. ~~Weather and location services, dashboard~~ done
4. ~~Skin type quiz, writing to `UserProfile`~~ done
5. ~~Tanning timer with flip and reapply alerts, live activity~~ done (Live Activity unverified
   on device, needs signing)
6. ~~Tan tracker with SwiftData sessions and photos~~ done
7. ~~UV forecast with Swift Charts~~ done
8. ~~History and insights~~ done
9. ~~Settings, data export, disclaimers~~ done
10. ~~Localisation pass~~ done. App Store assets drafted in `APPSTORE.md`, TestFlight blocked on
    Umut's Apple Developer account.
11. ~~Social sharing, family leaderboard~~ done (2026-07-21)
12. ~~Apple Watch app~~ done, launched and verified stable on simulator (2026-07-23)

Post-v1: Apple Watch complications, post-tan care tips.

## Decisions

**Xcode 26 synchronised folder groups, hand-written pbxproj.** Chosen over XcodeGen and Tuist
because Umut never opens Xcode, and synchronised groups mean new files need no project-file
edit at all. No third-party tool in the build path.

**`UVDataProviding` protocol with three implementations.** Not testing purism: WeatherKit is
unavailable in SwiftUI previews, unavailable offline and metered. `SampleUVProvider` models a
realistic half-sine UV curve so previews are deterministic.

**Cache sits behind the provider, not beside it.** Callers never branch on data origin; they
read `UVReport.source` only to tell the user. A failed refresh never blanks a reading already
on screen, because someone on a beach with no signal is better served by a stale number.

**Sunscreen SPF is discounted 50%.** Real-world application is roughly a third of the
2 mg/cm² used in lab certification. Quoting nominal SPF would tell an SPF 50 user they have
twenty hours. The honest number is the safe one.

**No ViewModel unless a screen coordinates async work.** `DashboardModel` exists because it
owns refresh orchestration and failure state. A screen that renders a struct gets none.

**English is the source language; Turkish is the translation.** Reversed on 2026-07-23 from the
original Turkish-source arrangement, because the App Store record's primary locale is `en-US`
and a catalogue whose source is Turkish makes English the fallback that silently ships raw
Turkish. The market framing is unchanged and deliberate: `SkinType.detail` still references
Karadeniz, Ege and Güneydoğu rather than generic northern European phenotype descriptions,
because types III and IV dominate this market. Source language is a mechanical choice about
which side is the fallback; it is not a decision about who the app is written for.

**A string's catalogue is decided by the bundle it is displayed from, not the file it is written
in.** `UVCategory.title` lives in `Bronzla/Models/UVSnapshot.swift` and is compiled into the
watch target as a second `PBXFileReference` (see the Apple Watch section). Its strings were
extracted only into the phone catalogue, so on the watch `Bundle.main` found no key and
`LocalizedStringResource` fell back to the English literal: a Turkish watch showed "Very high"
under a Turkish heading. This compiles clean, passes every test, and is invisible to any
catalogue-completeness count, because each catalogue is internally complete. **Any shared file
added to a second target needs its strings extracted into that target's catalogue too.** The
three catalogues are `Bronzla/Resources` (359), `BronzlaWidgets` (19), `BronzlaWatch` (16).

**CoreLocation via `CLLocationUpdate.liveUpdates`, not the delegate.** `CLLocationManagerDelegate`
is not actor-annotated, so bridging it onto the main actor smuggles a main-actor-isolated object
through a `nonisolated` callback. Swift 6 rejects it as a data race, and it is right to.
`CLLocationManager` is retained only for authorisation, which never crosses isolation.

**Timer state is a pure struct with an injected clock.** Elapsed time is always computed from
wall-clock `Date`, never accumulated by ticks, because the core use case is locking the phone
and putting it in a bag. `TimelineView` drives redraws; it never drives state. Notifications
are scheduled up front so they fire even if iOS terminates the app.

**ForecastView reuses `DashboardModel` rather than a bespoke model.** Same single-fetch
coordination as "Bugün"; the forecast screen just renders more of the `UVReport` that fetch
already returns (`report.hourly`, `report.daily`). Confirms the "no ViewModel unless a screen
coordinates async work" rule scales to a second screen without duplicating orchestration.

**Chart gradients derive from `Palette.colour(forUVIndex:)`, never a fixed palette.** Built as
`LinearGradient(colors: hours.map { Palette.colour(forUVIndex: $0.uvIndex) }, ...)` so the
curve's colour genuinely tracks the UV scale rather than an approximation of it.

**`burnRisk` and `UVCategory` are different scales; never feed one into the other's thresholds.**
`Palette.colour(for: UVCategory)` is calibrated for raw UV index (0 to 12+). `burnRisk` is a
dose fraction (dose ÷ MED, typically 0 to 1.5). `StreakCalendarView` maps burn risk onto
`UVCategory` cases itself (`<0.5 low, <0.8 moderate, <1.0 high, <1.3 veryHigh, else extreme`)
before handing it to `Palette.colour(for:)`; it never calls `UVCategory(uvIndex:)` on a risk
value. Any future screen colouring by burn risk needs the same private mapping, not the
UV-index initialiser.

**Photo actors must be built on `Data`, never `UIImage`, across the isolation boundary.**
`UIImage` is not `Sendable`. `SessionPhotoStore` (actor) resizes and JPEG-encodes via a
`nonisolated static func encodeJPEG(from: UIImage) -> Data?` that runs on the caller's own
isolation domain (no `await`, no actor-state access), so only `Data`/`String`/`URL` ever
cross into the actor's `save`/`loadData`/`delete` methods. This is the general pattern for any
future actor that has to touch UIKit/AppKit types under strict concurrency.

**`InsightsSummary.make` and `InsightsSummary.streaks` take plain arrays of SwiftData `@Model`
objects and run synchronously, no isolation crossing involved.** `@Model` classes are not
`Sendable`, but that only matters when a value crosses an `await` or into an actor; a static
func called directly on the caller's own actor (main thread in the view, background thread in
`Testing` by default) never triggers the check. This is why `InsightsTests.swift` constructs
bare `TanSession`/`UserProfile` instances with no `ModelContainer` at all, and it built and ran
clean under `-strict-concurrency=complete`.

**Streak logic lives once, in `InsightsSummary.streaks(for:referenceDate:calendar:)` (in
`InsightsView.swift`), and `StreakCalendarView` calls it rather than recomputing.** Keeps the
headline number on the tracker tab and the "en uzun seri" figure on the insights screen
mechanically unable to disagree.

## Verified state (2026-07-20)
Build green on iOS 26.3 simulator (BUILD SUCCEEDED, zero errors). Forecast peak-window tests
(4 cases in `ForecastTests`) pass under Swift 6 strict concurrency complete.

**Aftercare (`Features/Aftercare/AftercareAdvice.swift`) adds its own `Severity` enum rather
than reusing `UVCategory` for burn-risk tiers.** Same "different scales" rule as the
`burnRisk`/`UVCategory` entry above, but the tier count also differs (4 aftercare tiers vs 5 WHO
bands), so a shared enum would force an awkward mapping either way. `Severity` exposes a
`uvCategory` computed property (`routine→low, attentive→high, mild→veryHigh, serious→extreme`)
purely so `Palette.colour(for:)` can be reused for the accent colour; nothing else treats the two
enums as interchangeable. Boundaries are half-open low (`..<0.5`, `..<1.0`, `..<1.5`, else): the
boundary value itself belongs to the more cautious tier, matching how `burnRisk == 1.0` already
means "reddening expected" rather than "about to happen".

**Turkish folk sunburn remedies needed explicit, sourced-feeling corrections, not just silence.**
Yoghurt and cool compresses are genuinely fine and are recommended; olive oil on a fresh burn is
a widely believed but harmful folk remedy (it traps heat) and is called out by name in the
"do not" list at every tier from "attentive care" upward, phrased as a common belief that turns
out to be wrong rather than as mockery. Toothpaste, vinegar and direct ice are also warned
against. This is domain content a future aftercare screen (or a "myths" card) should keep intact
rather than genericise into "avoid home remedies".

**`DailyUVAlertScheduler` mirrors `NotificationScheduler`'s `Sendable` struct shape but needed
one extra trick: a stored `UserDefaults` property.** `UNUserNotificationCenter` is handled by
making it computed (`NotificationScheduler`'s existing pattern), but `UserDefaults` has to be
stored (constructor-injected, matching `TanTimerModel`'s `init(defaults: UserDefaults = .standard)`
convention) so the `isEnabled` opt-in flag can be tested against an isolated `UserDefaults(suiteName:)`
instance. `UserDefaults` is not `Sendable`-annotated even though it is internally thread-safe, so
the stored property needs `nonisolated(unsafe) private let defaults: UserDefaults` to keep the
struct's own `Sendable` conformance under `-strict-concurrency=complete`.

**Local `xcodebuild test` reliability gotcha on this machine: a stale on-disk SwiftData store
from an earlier, since-changed schema (e.g. a concurrent agent mid-edit on `UserProfile.swift`)
crashes the whole test host at launch with `EXC_BREAKPOINT`/`SIGTRAP` inside
`BronzlaApp.container`'s `fatalError("SwiftData store could not be opened...")`, which xcodebuild
reports as an opaque "Early unexpected exit, operation never finished bootstrapping" with zero
useful diagnostics in the piped log. Fix: `xcrun simctl uninstall <device-id> com.hmdcorp.bronzla`
to clear the simulator's persisted store before rerunning `xcodebuild test`. Check
`~/Library/Logs/DiagnosticReports/Bronzla-*.ips` (`threads[].triggered → frames`) for the actual
crashing frame when a test run fails with no error lines to grep.

## Environment blockers
- `DEVELOPMENT_TEAM` is empty in `project.pbxproj`. WeatherKit needs the real Team ID and an
  App ID with the WeatherKit capability enabled before live UV data works on device. Until then
  the app builds and runs, but `WeatherKitUVProvider` returns nothing and the dashboard shows
  its failure state on a real fetch.

## Multi-profile support (added 2026-07-20)

**New non-optional `@Model` stored properties need an inline default, not just an `init`
default, or lightweight migration crashes at launch.** Adding `UserProfile.name: String`,
`isActive: Bool`, `colourHex: String` with only `init(... name: String = "" ...)` compiles fine
but crashes any simulator/device that already has an installed build with the old schema:
`CoreData: error: ... Validation error missing attribute values on mandatory destination
attribute`, surfacing in-app as `fatalError("SwiftData store could not be opened: ...")` in
`BronzlaApp.swift`. The fix is `var name: String = ""` etc. declared on the stored property
itself, which SwiftData's automatic lightweight migration can read to backfill existing rows.
`xcodebuild test` will not catch this on a truly fresh ephemeral test-runner simulator; it only
reproduces once a real device/simulator has an old build's on-disk store, e.g. `xcrun simctl
launch --console <udid> com.hmdcorp.bronzla` after `simctl install` of the old and then new
build in sequence. Worth checking any time a `@Model` gains a non-optional field.

**`PersistentModel.persistentModelID` exists on unsaved, container-less instances.** Domain
logic that needs to compare/identify `@Model` objects (`ActiveProfileResolution` in
`ActiveProfileStore.swift`) can be pure, static and tested with plain `UserProfile()` instances,
no `ModelContainer`, matching the existing `InsightsSummary`/`InsightsTests` pattern. `@Model`
classes conform to `Identifiable` too (`id == persistentModelID`), so `.sheet(item:)` works
directly on them without a wrapper struct.

**`ActiveProfileStore` is `@MainActor @Observable`, instantiated locally per-view (`@State
private var activeStore = ActiveProfileStore()`), not injected via `.environment(...)` at the
app root.** It only wraps a `UserDefaults` read/write of an encoded `PersistentIdentifier`
(`PersistentIdentifier` is `Codable` and `Sendable` but not a plist type, so it needs
`JSONEncoder`/`JSONDecoder` round-tripping through `Data`), so every instance is always
consistent with every other; no shared singleton or environment plumbing needed. This matters
because `BronzlaApp.swift`/`RootView.swift` were out of scope for the task that introduced this
store, so environment injection at the root was not an option anyway. Screens outside that
task's scope (Dashboard, Timer, Forecast, Tracker, History) still read `@Query`'s
`profiles.first`, which is **not** guaranteed to be the active profile: SwiftData's default,
unsorted `@Query` order does not track `UserProfile.isActive`. Any of those screens becoming
profile-aware needs either a sort on `isActive`/`createdAt` or its own `ActiveProfileStore`
lookup, mirroring `SettingsView`'s `activeStore.profile(in: profiles)` pattern.

**Fixed accent-colour palette, not the system `ColorPicker`.** `ProfilePalette.swatches` in
`ProfileEditorView.swift` (six hex strings) plus a `Color(hex:)` failable initialiser. Keeps
every profile's colour inside the app's restrained palette rather than an arbitrary user pick.

## Social sharing (added 2026-07-21)

**`BronzScore` scores discipline, never exposure or duration; `burnPenalty` (25) exceeds any
single reward so grinding clean sessions can never make a burn worth it.** This is the load-
bearing decision for the whole social feature. Every future badge, card or leaderboard entry
must be checked against it before shipping: if it rewards staying out longer, being darker, or
logging more hours, it inverts a sun-safety app's purpose.

**`ShareCardButton` renders lazily, on tap, not eagerly on appear.** Most sessions are never
shared; running `ImageRenderer` for cards nobody looks at would be pointless work at 3x scale.

**Instagram Stories handoff needs a real array-typed Info.plist file, not `INFOPLIST_KEY_`.**
`INFOPLIST_KEY_LSApplicationQueriesSchemes` (array) silently produces no key at all in the
generated Info.plist; verified empirically with `PlistBuddy -c "Print :LSApplicationQueriesSchemes"`
before trusting it. Same failure class as the widget's `NSExtension` dictionary. Fixed with
`Config/Bronzla-Info.plist` + `INFOPLIST_FILE`, merged by `GENERATE_INFOPLIST_FILE`. **Rule for
this project: any Info.plist key whose value is an array or dictionary needs a partial `.plist`
file; only scalar values (string, bool, number) work through `INFOPLIST_KEY_`.**

## Apple Watch target (added 2026-07-21)

**Hand-added `BronzlaWatch` as a fourth `PBXNativeTarget`, object ID prefix `AC` (all previous
targets use `AA`/`AB`), applied via a one-shot Python script for atomicity rather than
sequential `Edit` calls.** A multi-section pbxproj change like this touches ~14 sections that
all have to agree (`PBXBuildFile`, `PBXFileReference`, `PBXFileSystemSynchronizedRootGroup`,
`PBXFrameworksBuildPhase`, `PBXGroup`, `PBXNativeTarget`, `PBXProject`,
`PBXCopyFilesBuildPhase`, `PBXResourcesBuildPhase`, `PBXSourcesBuildPhase`,
`PBXTargetDependency`, `PBXContainerItemProxy`, `XCBuildConfiguration`,
`XCConfigurationList`); a script with asserted string anchors either applies cleanly or fails
before writing anything, whereas 14 sequential `Edit` calls leave the file in an unknown
partial state if one fails partway. Verify every multi-line anchor string against the actual
file (`python3 -c "print(repr(...))"`) before running the script — tab depth differs by
section and a wrong guess fails the assertion harmlessly, but only if you check first rather
than trust memory of "the pattern".

**Shared domain files are added to the watch target as separate, explicit
`PBXFileReference`s pointing at the same on-disk path, never moved.** `SkinType.swift`,
`UVSnapshot.swift` and `ExposureCalculator.swift` physically live under `Bronzla/Models/` and
`Bronzla/Services/Exposure/`, inside the `Bronzla` folder's `PBXFileSystemSynchronizedRootGroup`
(which auto-adds them only to the `Bronzla` target). A second, independent `PBXFileReference`
with the same relative `path`, placed in a plain (non-synchronized) `PBXGroup` with no `path`
of its own so children resolve relative to the project root, plus a `PBXBuildFile` only in the
watch target's `Sources` phase, adds the file to a second target without touching the original
group or duplicating the file on disk. This is the general pattern for any future target that
needs to share code living inside another target's synchronized folder.

**The watch app gets its own `WeatherAttributionView` twin (`WatchWeatherAttributionView`),
not the phone's.** The phone version depends on `Spacing`, a design-token type; pulling it
across for one small link would drag layout code the watch has no other use for. Both show
WeatherKit data, so both need attribution — same non-negotiable, two small implementations.

**Watch app embedded into the iOS app via a `PBXCopyFilesBuildPhase`, not a WatchKit
extension.** Modern single-target watch app model: `dstSubfolderSpec = 16` (Products
Directory), `dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"`, plus a `PBXTargetDependency` so the
watch app builds before the iOS app tries to embed it. `WKApplication = YES` and
`WKCompanionAppBundleIdentifier = com.hmdcorp.bronzla` are both scalar Info.plist values and
work fine through `INFOPLIST_KEY_`; no partial plist file was needed for the watch target
(unlike the widget's `NSExtension` dict or the app's `LSApplicationQueriesSchemes` array).

**`WATCHOS_DEPLOYMENT_TARGET = 11.0`, `SDKROOT = watchos`, `TARGETED_DEVICE_FAMILY = 4`,
`SUPPORTED_PLATFORMS = "watchsimulator watchos"`.** 11.0 chosen to pair with the app's
`IPHONEOS_DEPLOYMENT_TARGET = 18.0` (the generation before Apple's 2025 platform-version
renumbering, when watchOS 11 shipped alongside iOS 18); the installed simulator runtime is
"watchOS 26.2" under the new naming, which is that same generation.

**Verified with `xcodebuild build -scheme Bronzla` only — the watch app has never actually
been launched.** Compiling and embedding cleanly is necessary but not sufficient; nobody has
watched `WatchDashboardView` render or `WatchUVModel.refresh()` execute in a simulator. Do not
report the watch feature as working until that has happened. See `RESUME.md` Step 1.
**Update 2026-07-23: done.** See "Watch app launched (2026-07-23)" below.

## Desktop is iCloud-synced — a hazard for every future session (discovered 2026-07-23)

**`~/Desktop`, and therefore this whole project, syncs through iCloud Drive's "Desktop &
Documents Folders". Some source files can be genuinely absent from the local disk while still
existing in the cloud, and materialize late, mid-session, with no warning.** This bit hard at
the start of this session: a plain build failed with "cannot find 'TimerRing' in scope" and
`find`/`ls` on the `Components/` folder showed it completely empty, not even a placeholder. The
natural read was "these files were never created despite RESUME.md's claim." That read was
wrong. `TimerRing.swift`, `StreakCalendarView.swift`, `HourlyUVChart.swift` and `DailyUVRow.swift`
all existed, correctly, dated 2026-07-20 — they were simply cloud-only and had not been faulted
in to local disk yet. Running `brctl download <path>` and waiting several seconds is what
triggers materialization; a plain `find` or `ls` gives no signal that a file is merely offline
rather than missing.

**The real danger: if you write a new file at the same path while the cloud original is still
downloading, iCloud does not overwrite either one — it silently renames the incoming download to
`"<name> 2.swift"`, and your new file keeps the original name.** This happened twice this session
(`TimerRing.swift`/`TimerRing 2.swift`, `StreakCalendarView.swift`/`StreakCalendarView 2.swift`,
`HourlyUVChart.swift`/`HourlyUVChart 2.swift`, `DailyUVRow.swift` materialized before a collision
occurred). The build then fails with "ambiguous use of" rather than anything mentioning iCloud,
which is a confusing error to land on. In every case the " 2" file was the genuine, more complete
original; the freshly-written file was a plausible-looking but inferior reimplementation done
without knowledge that the real thing already existed.

**Rule for every future session on this project: before concluding any expected file is
"missing" or a "Components" folder is genuinely empty, run `brctl download <path>` on the
containing directory (or the whole project root) and wait 10-15 seconds, then re-check.** Only
write a replacement file if it is still absent after that. If a `" 2"` file ever appears after a
write, diff it against what you just wrote before deciding which one to keep — the " 2" file is
very likely the pre-existing, previously-verified original, not a stray duplicate to discard.
`brctl status` can also show a project-wide list of pending syncs and conflicts if the picture is
still unclear; this session's run surfaced unrelated, pre-existing sync conflicts in a sibling
`Desktop/GLASS` project (unrelated to Bronzla, not actioned, worth Umut's awareness separately).

## Watch app launched (2026-07-23)

**`BronzlaWatch` installs, launches and renders correctly on the Apple Watch Series 11 (46mm)
simulator, and stays running without crashing.** Verified by screenshot (correctly shows the
Turkish `CLLocationUpdate` permission prompt: `"Bulunduğunuz yerin güncel UV indeksini
gösterebilmek için konumunuza ihtiyacımız var. Konum bilgisi cihazınızda kalır."`) and by
`launchctl list`/`log show` on the simulator showing the process alive with no crash, fault or
fatal log lines. `simctl privacy grant location` did not pre-empt the system permission prompt
on a reused install; only an uninstall + reinstall + pre-grant, before the very first launch,
avoided it — and even then a stale already-presented prompt on screen was not dismissed by
`simctl terminate` (it reported "found nothing to terminate", meaning the app process had
already exited while the system-owned prompt stayed on screen). **`simctl erase` on the
simulator is blocked by this machine's `guardrail.py` hook as a destructive power-state change**;
do not fight it, use `simctl uninstall`/`install` on the one app instead, which is not blocked
and was sufficient here.

**Never reached the `.loaded` dashboard state — no tooling was available to tap "Allow" on the
system prompt.** `simctl` has no touch-injection command for watchOS. An attempt to drive it via
macOS Accessibility (`osascript` + System Events on the Simulator app) hung for the full 2-minute
timeout, almost certainly waiting on a first-run macOS Accessibility permission grant that
requires interactive approval this session cannot give. This is a tooling gap, not evidence of
an app problem: the app is confirmed stable and correctly localized up to the permission gate.
A future session with a human at the keyboard (or a pre-authorized Accessibility grant) could
tap through and confirm `WatchUVModel.refresh()` executes past that point.

## Marketing site

Lives in `web/`, deployed separately to Cloudflare. Its own brain is `web/MEMORY.md`;
nothing about the website belongs in this file.

## App Store Connect, signing and TestFlight (added 2026-07-23)

**Credentials.** Not recorded here, deliberately. The App Store Connect API key id and issuer
id live in App Store Connect under Users and Access > Integrations; the private key is at
`~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8` (chmod 600, kept out of iCloud on purpose)
and is the only true secret. Never read the `.p8` into context, echo it, or commit it. The team
id is in `project.pbxproj` as `DEVELOPMENT_TEAM` if you need it. A venv at `/tmp/asc_venv` has pyjwt/requests for
minting the ES256 JWT (20 min max expiry, `aud: appstoreconnect-v1`).

**What the API cannot do, and never guess otherwise.** Three things in this pipeline have no
API and must be done in the web portal by a human: enabling the **WeatherKit capability** on an
App ID (`WEATHERKIT` is rejected by `POST /v1/bundleIdCapabilities` even though third-party
client libraries list it), **creating an App Group**, and **creating the App Store Connect app
record**. Everything else (bundle IDs, certificates, profiles, beta groups, testers, feedback,
build status) is fully scriptable. When an enum value is rejected, the error body lists the
complete accepted set: read it rather than searching, that is the authoritative answer.

**Signing is manual, deliberately.** Automatic signing repeatedly resolved to *Development*
profiles in this headless session and then failed with "no devices ... to generate a
provisioning profile", which is a red herring: App Store distribution needs no registered
device. Setting `CODE_SIGN_IDENTITY = "Apple Distribution"` while `CODE_SIGN_STYLE` stayed
`Automatic` produced a hard conflict error. The working configuration is `CODE_SIGN_STYLE =
Manual` plus an explicit `PROVISIONING_PROFILE_SPECIFIER` per target, with an RSA-2048 CSR
(not ECDSA) posted to `/v1/certificates` and the profiles fetched and dropped into
`~/Library/MobileDevice/Provisioning Profiles/`. **The watch target's specifier must not carry
an `[sdk=iphoneos*]` qualifier** — it builds for watchOS, so the qualifier silently excluded it
and produced a confusing "requires a provisioning profile with the WeatherKit feature" error.

**Shared schemes must exist on disk.** `xcuserdata` claimed three shared schemes while
`xcshareddata/xcschemes/` did not exist; Xcode was synthesising them, and archive could not
resolve them properly. Real `.xcscheme` files are checked in now.

## The Info.plist rule, now with four confirmed instances (2026-07-23)

**`INFOPLIST_KEY_<Key>` only carries scalars. Arrays, dictionaries, and any key outside Xcode's
supported allowlist are silently dropped — no error, no warning.** Confirmed instances:
1. the widget's `NSExtension` dictionary
2. the app's `LSApplicationQueriesSchemes` array
3. the watch's `CFBundleIconName` (a *string*, but not on the allowlist, so still ignored)
4. `UILaunchScreen` via `INFOPLIST_KEY_UILaunchScreen_Generation`, which emitted the key
   **nested inside itself** (`{UILaunchScreen: {UILaunchScreen: {}}}`)

Number 4 shipped in build 1 and caused a real user-visible bug: iOS silently ignores a malformed
`UILaunchScreen` and runs the app in **320pt iPhone SE compatibility mode**, which is what
"black sides on screen" was. The fix in every case is a real partial `.plist` referenced by
`INFOPLIST_FILE`, merged by `GENERATE_INFOPLIST_FILE`. **Always verify a new Info.plist key in
the built product with PlistBuddy; never assume the build setting took.**

## English is the source language (changed 2026-07-23)

Umut's call: English is the app's source and fallback so a device set to neither Turkish nor
English gets English. Store listing primary locale is `en-US`. Turkish remains a complete,
first-class translation and Türkiye remains the first market.

**A bug was found while sizing this, and it had shipped.** 101 of 350 catalogue strings had no
English localisation at all, so English users saw Turkish across every Phase 2/3 screen. An
earlier session reported "418 strings, 0 untranslated" — that check grepped the exported xliff
for `state="new"`, which does **not** flag a string with no target element. **The correct check
is to count entries whose target localisation is absent, not entries marked new.** The current
catalogue is verified the honest way: 348 entries, `sourceLanguage: en`, 0 missing a Turkish
value.

**Interpolated strings never reach the catalogue.** A mapping-driven refactor structurally
cannot see `"\(minutes) dk"`, so hardcoded Turkish survived in 8 places across all three
targets, including `TimerRing.spoken()` (the VoiceOver string) and share-card images. Fixed with
locale-aware `Duration.formatted(.units(allowed:width:))` rather than swapping in English
literals, so neither language is hardcoded. Note `zeroFieldBehavior:` is not accepted in that
overload here; vary the `allowed` set instead.

**UI tests deliberately run in Turkish** (`-AppleLanguages (tr)` in `setUp`) because Turkish
strings are materially longer and surface truncation first. That rationale is now stronger, not
weaker: Turkish is the translated side and can rot silently. Assertions stay Turkish. When a
UI test fails on a string, check whether the source literal still matches the catalogue key
exactly: `"Question %lld / %lld"` vs the catalogue's `"Question %lld of %lld"` silently defeated
the lookup and rendered English under a Turkish run.

**An InfoPlist catalogue needs the source-language value too.** A `InfoPlist.xcstrings`
containing only `tr` made the English permission prompt display the raw key name
(`NSLocationWhenInUseUsageDescription`) to the user. Include `en` explicitly.

## Version control (added 2026-07-23)

`github.com/umutguden/bronzla`, **private**, default branch `main`. Initial commit `4d3a47b`
imports the whole project (151 files, ~21k lines) including the Astro site under `web/` for
bronzla.app. Before that commit there was no version control at all; the only prior safety net
was `~/bronzla-pre-i18n-refactor-20260723-0338.tar.gz`.

**`~/.claude/hooks/pre-push-protection.sh` blocks any push while the local branch is `main` or
`master`, and blocks force-push anywhere.** It is a PreToolUse hook, so it evaluates the branch
*before* the command runs: renaming the branch and pushing in one compound command still trips
it. Split them into separate calls. All future work goes on a branch and lands via PR.

`main` was created server-side with `gh api repos/.../git/refs` rather than pushed, because a
brand-new repository has no base branch to open a PR against. That was a one-off for the initial
import and Umut approved it explicitly; it is not a pattern to reuse.

Nested `.gitignore` files are honoured, so `web/dist/` and `web/node_modules/` stayed untracked
without any root-level entry. Shared schemes under `Bronzla.xcodeproj/xcshareddata/` are tracked
deliberately (see the signing section: archiving needs them to exist on disk).

## Checking TestFlight build status (added 2026-07-23)

**`GET /v1/builds?filter[app]=<id>` does not list builds that are still processing.** A build
uploaded minutes earlier is simply absent from that response, which reads identically to "Apple
rejected it". This nearly produced a false report that builds 3 and 4 had failed.

Use `GET /v1/preReleaseVersions?filter[app]=<id>&include=builds` instead: it returns every build
with its real `processingState` (`PROCESSING`, `VALID`, `INVALID`, `FAILED`). Poll that when
waiting for a build to become installable.

Also note `xcodebuild -exportArchive` printing **"Upload succeeded" only means Apple accepted the
package for delivery**, not that it passed processing. A build can upload cleanly and still never
appear. Always confirm `VALID` before telling anyone a build is ready.

## WeatherKit needs enabling in TWO places (root-caused 2026-07-23)

`WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors error 2` on device, with the entitlement
correctly present in the signed binary and the profile, means WeatherKit is enabled as a
**Capability** on the App ID but not as an **App Service**. They are two separate lists on the
same identifier page in the developer portal, and both must be ticked. Only the capability is
reachable through the App Store Connect API (`bundleIdCapabilities`); App Services is portal-only,
like the app record and App Groups.

This cost builds 1 through 5. The entitlement being present in `codesign -d --entitlements` is
**not** sufficient evidence that WeatherKit will work, which is what made it hard to spot: every
check I could run from the API said it was configured. The JWT handshake is the only thing that
proves it.

After ticking App Services, regenerate the provisioning profiles (the API can do this) and
rebuild. Apple's backend can still lag by hours, and there is a known sync bug that needs a
Developer Support ticket per Team ID if it persists.

Diagnosing this needed the error text off the device. The tester had no cable, so Console.app was
unavailable and the OSLog line added in build 4 was unreachable. Build 5 surfaced the underlying
error in the failure view instead, which is what produced the answer. Keep that affordance until
the app ships; it is the only diagnostic channel when the tester cannot attach a Mac.

## Screenshot mode for App Store captures (added 2026-07-23)

`-screenshotMode` launch argument, DEBUG-only, added in `Bronzla/App/ScreenshotSeed.swift`,
wired into `BronzlaApp.swift` alongside the existing `-uiTestingFreshState` precedent.

**An in-memory `ModelContainer` and a fixed `UVDataProviding` are not enough on their own.**
`DashboardView.refresh()` early-returns when `locationService.place == nil`, and in a fresh
simulator there is no route to a real CoreLocation fix, so the dashboard sits in `.loading`
forever regardless of what the UV provider returns. Screenshot mode also has to set
`LocationService.manualPlace` (a `@MainActor`-isolated property) before the first render.

**`UVReport.source` must be `.live`, not `.sample`.** `DashboardView` renders a "Showing sample
data" banner for `.sample` and a staleness notice for `.cached` or `isStale`. A screenshot
provider should wrap `SampleUVProvider` (reusing its diurnal curve) and then rebuild the
`UVReport` with `current.uvIndex` pinned and `source: .live`, `fetchedAt: .now`, rather than
inventing a new curve generator.

**`FamilyBoardView` needs 2+ `UserProfile` records with sessions attributed to each, or the
ranking screen is degenerate** (empty or single-row). Easy to miss because "family ranking" only
shows up as a screen name, not a model requirement, when reading `UserProfile`/`TanSession` in
isolation.

**`ModelContext.mainContext` access requires `@MainActor` on the calling function**, even inside
a `#if DEBUG`-only static seeding helper; the compiler does not infer it from call-site context.

**Streak maths (`BronzScore.streaks(for:)`) counts distinct calendar days, not session count.**
To hit a specific current/longest streak pair deterministically, seed two separated blocks of
consecutive calendar days (a longer one anywhere in the past for `longestStreak`, a shorter one
ending today for `currentStreak`), then pad session *count* separately by adding a second
same-day session on a few of those days without adding new days.

**Today's seeded session must be anchored to `Date.now`, not a fixed hour-of-day**, or it can
land in the future relative to the actual capture time depending on when the screenshot run
starts. Compute `startedAt = max(startOfToday, now - duration - buffer)` instead.

## BronzlaWidgets and BronzlaWatch localisation and attribution (added 2026-07-23)

Both extension targets are `PBXFileSystemSynchronizedRootGroup`s. Dropping a plain
`Localizable.xcstrings` at the root of `BronzlaWidgets/` or `BronzlaWatch/` is picked up by the
sync group with no `project.pbxproj` edit: confirmed by `xcstringstool compile` appearing in the
build log for both, and by `tr.lproj/Localizable.strings` landing in the built `.appex`/`.app`.

**`Text(_:)` and `Label(_:systemImage:)` only auto-localise when the argument is a literal
written directly at the call site.** Passing the same literal through an intermediate
`String`-typed function parameter (e.g. a shared `message(_ title: String, ...)` helper) silently
switches SwiftUI to the verbatim `StringProtocol` overload and the catalogue entry is never
looked up, no warning, no error. Fix is to type the parameter `LocalizedStringKey`, not `String`.
Same trap applies to values built through `.map`/`??` closures assigned to a `Label`/`Text`
first argument (`BronzlaWidgets/UVWidget.swift`'s `accessoryInline`, formerly
`snapshot.map { "..." } ?? "..."`): resolved by calling `String(localized: "...")` explicitly at
each branch, which accepts a literal `String.LocalizationValue` interpolation (so keys still get
`%@`/`%lld` placeholders) and returns an already-resolved `String` handed to the verbatim
overload deliberately.

**Trademark text (Apple's WeatherKit "Weather" mark) must use `Text(verbatim:)`, not a catalogue
key.** A trademark is not translated between locales; routing it through `Localizable.xcstrings`
risks a future translator "fixing" it into Turkish. Both the widget and the Live Activity render
it as `Text(verbatim: "Weather")`, `.caption2`, `.foregroundStyle(.tertiary)`, no link (widgets
cannot open URLs from arbitrary subviews). `accessoryCircular` and `accessoryInline` deliberately
carry no attribution (single glyph / single line, no room); comment left at both skip sites. The
Live Activity's lock screen banner also deliberately carries no attribution, only the Dynamic
Island expanded region does, per explicit product decision, not an oversight.

**Latent bug found, not fixed (out of scope, lives under `Bronzla/` and `Shared/`):**
`SharedUVCategory.localisedTitle` (`Shared/SharedUVSnapshot.swift`, dual-compiled into
`BronzlaWidgets`) and `UVCategory.title` (`Bronzla/Models/UVSnapshot.swift`, dual-compiled into
`BronzlaWatch`) both call `String(localized:)`/return `LocalizedStringResource` for band names
("Low", "Moderate", "High", "Very high", "Extreme"). These resolve against each *process's own*
`Bundle.main`, i.e. the widget extension's or the watch app's own bundle, not the phone app's.
Neither `BronzlaWidgets/Localizable.xcstrings` nor `BronzlaWatch/Localizable.xcstrings` (both new,
2026-07-23) contains those five keys, because the literals themselves live outside the widget and
watch source trees. Until someone with write access to `Bronzla/` and `Shared/` adds those keys to
the widget/watch catalogues (or duplicates the enum), the UV category badge on both extensions
will silently render in English on a Turkish device, with no build error.

## Backend (`infra/`, added 2026-07-26)

AWS CDK (TypeScript) app for a new dedicated Bronzla AWS account (not yet created; deploy is
blocked pending Umut, not a technical gap). `BronzlaBackendStack-dev`: three DynamoDB tables
(`BronzlaUsers`, `BronzlaSessions` with TTL + a `SessionsByAppleSub` GSI, `BronzlaScores` with a
`LeaderboardByScope` GSI), four Lambdas (`auth-apple`, `put-score`, `get-leaderboard`,
`delete-account`) behind an API Gateway HTTP API. `npx cdk synth` exits 0; `npx tsc --noEmit`
clean; `npx vitest run` is 19/19 green across five test files.

**Two CDK API surface mismatches, fixed:** `NodejsFunctionProps["bundling"]` is not indexable off
`NodejsFunction` itself (`NodejsFunction["bundling"]` does not exist as a type) — use
`NonNullable<import("aws-cdk-lib/aws-lambda-nodejs").NodejsFunctionProps["bundling"]>` instead.
`dynamodb.Table` has no `arnForIndex` method in the installed `aws-cdk-lib` version — build the
GSI ARN manually as `` `${table.tableArn}/index/${indexName}` `` for scoped `dynamodb:Query` IAM
policies.

**Auth is inlined per Lambda handler (`lambda/shared/session-auth.ts`), not a separate API
Gateway Lambda authoriser.** Documented, deliberate deviation from a naive "shared authoriser"
reading: at four routes, a dedicated authoriser resource (its own Lambda, IAM role, caching
config) is more moving parts than it saves, and inlining keeps each handler's 401 path in one
file. `expiresAt` is checked explicitly in application code rather than trusted to DynamoDB TTL
deletion, because TTL cleanup is eventually consistent and can lag well past the real expiry.

**Vitest env vars for Lambda handlers must be set in `vitest.config.ts`'s `test.env` block, not
inside a test file's own top-level `process.env.X = ...` line.** ES module imports are hoisted
ahead of a test file's own top-level statements, so a handler's module-level
`const TABLE = process.env.TABLE_NAME ?? ""` captures the empty string before the test file's own
`process.env` assignment ever runs. `test.env` in the Vitest config is applied before any test
module is imported, so it is visible from a handler's very first line. Symptom if this is missed:
`TableName: ""` showing up in mocked SDK call assertions despite the env var apparently being set.

**Delete-account fan-out is a primary `TransactWriteItems` (User + Score + up to 98 session
deletes, the 100-item transaction cap minus 2) followed by further all-session-only transactions
for any remainder.** Guarantees the account is atomically gone from the caller's perspective even
for a user with far more than 98 active sessions; a failure on a later batch surfaces as a 500,
never a partial-success 204, and a retry is safe because the User/Score deletes are idempotent
(deleting an already-deleted key succeeds).

## Security review log — infra/ (AWS CDK backend), 2026-07-26

Reviewed pre-deploy (never deployed). Vulnerability classes found, with the wrong
assumption and the invariant that replaces it:

- **Broken session invalidation on account deletion.** Wrong assumption: a GSI query
  returns every session a user owns, so deleting the query results revokes all access.
  Right invariant: GSIs are eventually consistent, so a bearer token can outlive the
  account row; every authorised request must confirm the owning user row still exists
  (consistent read), and sessions must be deleted before the user row, not after.
  `infra/lambda/delete-account.ts:78-96`, `infra/lambda/shared/session-auth.ts:54-70`.
- **Fail-open expiry check.** Wrong assumption: a session record always carries a numeric
  `expiresAt`. Right invariant: validate the type before comparing; a missing claim must
  fail closed, never pass. `infra/lambda/shared/session-auth.ts:61`.
- **Over-broad IAM for an authoriser read.** Wrong assumption: `grantReadData` on the
  sessions table is least-privilege for a token lookup. Right invariant: an authoriser
  needs `GetItem` on the table only; `Query`/`Scan` on a session table lets one
  compromised Lambda enumerate every live bearer token.
  `infra/lib/bronzla-backend-stack.ts:125,145,174`.
- **Pseudonymous identifier treated as non-PII in logs.** Right invariant: `appleSub` is
  a stable user identifier; log a truncated hash, not the value.
  `infra/lambda/shared/session-auth.ts:65`, `infra/lambda/auth-apple.ts:98`.
- **Sort-key encoding assumed integer input.** Validation allowed fractional scores,
  which break the fixed-width padding and therefore leaderboard ordering.
  `infra/lambda/shared/dynamo.ts:21`, `infra/lambda/put-score.ts:41`.

No secrets, no payment-key references, no injection or SSRF found. Apple identity-token
verification (`jose`, RS256, kid match, aud from env, iss, exp) is sound.

### Second security pass, 2026-07-26 (still pre-deploy)
Supersedes the closing line above: Apple identity-token verification is **not** sound when
`APPLE_BUNDLE_ID` is absent.

- **Audience check silently skipped on empty config (critical).** Wrong assumption: passing
  the audience option to `jwtVerify` enforces it. `jose@5` gates the comparison on
  `if (audience && ...)`, so an empty string is falsy and the `aud` value is never compared
  (it is only required to be present). With `APPLE_BUNDLE_ID` unset, the `?? ""` fallback
  turns the verifier into "any Apple-signed token for any app", i.e. full account takeover
  by any third-party app's identity token. Right invariant: assert every security-relevant
  environment variable is non-empty at module load and fail the cold start; never let a
  falsy config value degrade a check to a no-op. Confirmed empirically.
  `infra/lambda/shared/apple-jwt.ts:76,109`, `infra/lambda/auth-apple.ts:10`.
- **JWKS cache has no invalidation on `kid` miss.** An unknown `kid` returns a hard failure
  without refetching, so a warm container rejects every valid sign-in for up to an hour
  after Apple rotates keys. Right invariant: a `kid` miss is a cache-staleness signal, so
  refetch once (rate-limited) before failing. `infra/lambda/shared/apple-jwt.ts:99-102`.
- **Unvalidated JWKS response is cached.** The fetch result is cast, not shape-checked, then
  cached for an hour; one malformed 200 from Apple wedges all sign-ins. Right invariant:
  validate before caching, and never cache a response that fails validation.
  `infra/lambda/shared/apple-jwt.ts:36-52`.
- **Bearer tokens stored in plaintext.** Right invariant: a session table is a credential
  store; index by SHA-256 of the token so a table read is not directly replayable.
  `infra/lambda/auth-apple.ts:88-96`, `infra/lambda/shared/session-auth.ts:47-52`.
- **No server-side revocation path.** Sign-out is client-only, so a token lifted from the
  Keychain stays valid for its full 90 days. Right invariant: any long-lived opaque session
  needs a delete-the-row endpoint, not just local forgetting.
- **No stage throttling and unbounded log retention.** `/auth/apple` is unauthenticated by
  nature and does an outbound fetch per cold path; with no throttle it is a cost-DoS, and
  log groups default to never expiring while carrying `appleSub`.
  `infra/lib/bronzla-backend-stack.ts:91-187`.
- **Runtime dependency declared as dev-only.** `jose` sits in `devDependencies` although
  Lambda code imports it. `infra/package.json:19`.

## Security review notes — infra (backend), round two, 2026-07-26
- **Fail-open expiry check.** Wrong assumption: a missing `expiresAt` on a session row is
  impossible because TTL writes it. Invariant: an authorisation predicate must require the
  attribute's type, not just compare it (`typeof expiresAt === "number" && > now`).
  `infra/lambda/shared/session-auth.ts:86`.
- **Eventually consistent revocation.** Wrong assumption: a GSI query enumerates every
  session belonging to a user. Invariant: revocation must delete sessions before the row
  authorisation depends on, always include the token presented on the request, and back it
  with a `ConsistentRead` existence check. `infra/lambda/delete-account.ts:85`,
  `infra/lambda/shared/session-auth.ts:98`.
- **CDK grant helpers as least privilege.** Wrong assumption: `grantWriteData` is narrow
  because it is not `grantReadWriteData`. Invariant: it also grants DeleteItem, UpdateItem
  and BatchWriteItem; spell out actions when a handler only ever does PutItem.
  `infra/lib/bronzla-backend-stack.ts:115`, `:141`.
- **PII in logs.** Invariant: Apple `sub` is PII, only ever logged via `hashAppleSub`.
  `infra/lambda/shared/logger.ts:13`.

## iOS frontend patterns — leaderboard build, 2026-07-26
- **Session state is read fresh per screen, not shared via a second `@Observable`.** Both
  `FamilyBoardView`'s Global segment and `SettingsView`'s account row call
  `service.currentSession()` from their own `GlobalBoardModel` in `.task`, rather than lifting
  sign-in state into an app-wide observable like `LocationService`. `TabView` retains off-screen
  view state, so a shared object would have been the safer choice for instant cross-tab
  consistency, but the codebase's "no model unless a screen coordinates async work" convention,
  and Keychain reads being effectively free, made per-screen re-reads the better fit. Revisit if
  a sign-out in one tab ever needs to be reflected instantly in another already-visible tab.
- **Leaderboard score push is a full recompute, not a delta.** The backend's `BronzlaScores`
  table overwrites one row per user per push, so `TimerView` recomputes
  `BronzScore.make(from:)` over the profile's entire session history after each finish, the same
  call `FamilyBoardView` already made, and pushes `.total`. Pushing only the just-finished
  session's score would have been wrong against overwrite semantics.
- **`GlobalBoardModel` takes the service as a call parameter (`load(using:)`), never stores
  it**, matching `DashboardModel.load(from:place:)`. Keeps the model itself trivially testable
  and consistent with the one existing `@Observable` screen model in the codebase.

## Security review, 2026-07-26 (Sign in with Apple + leaderboard backend)
Vulnerability class: sensitive-data disclosure through a client-supplied public field, plus
stale-key availability failure in JWT verification.
- **Wrong assumption:** that requesting only `.fullName` (never `.email`) from Apple is by itself
  a minimal-disclosure posture. It is not: `AppleSignInView.swift:60-66` sends Apple's real
  given + family name straight to the server as `displayName`, which `get-leaderboard.ts` then
  publishes to every other user, directly contradicting the app's own copy ("Never your real
  name", `AppleSignInView.swift:21` and `SettingsView.swift:317`). The plan called for the name to
  be a *prefill* for an editable field; no editor was built, so the prefill became the value.
- **Right invariant:** a field that is published to other users must be typed or confirmed by the
  user before its first transmission. Never let an identity-provider-supplied real name become a
  public value by default.
- **Wrong assumption:** an unknown `kid` means "bad token". It also means "Apple rotated keys", so
  a hard reject against a cached JWKS fails closed but bricks all sign-ins for the cache TTL
  (`apple-jwt.ts:112`, fixed: refetch once on kid miss, floored at one refetch/minute so an
  attacker-supplied random `kid` cannot amplify requests to Apple).
- Verified-good patterns worth keeping: allow-list response projection in `get-leaderboard.ts:67`
  rather than deleting fields; `hashAppleSub` so the raw `sub` is never logged
  (`shared/logger.ts:13`); explicit `expiresAt` check instead of trusting DynamoDB TTL as the
  security boundary (`shared/session-auth.ts:86`).
