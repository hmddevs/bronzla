# Bronzla — project brain

## Current phase
Feature-complete for v1.0, as of 2026-07-23. All five tabs, social sharing, the family
leaderboard and an Apple Watch app are built. All three targets (`Bronzla`, `BronzlaWidgets`,
`BronzlaWatch`) build clean in Release from wiped DerivedData, zero compiler warnings. 140 unit
tests and 5 UI tests all pass. Localisation is complete (418 strings, 0 untranslated). What
remains is entirely outside code: `DEVELOPMENT_TEAM`, WeatherKit capability on both App IDs, a
watch app icon, App Store Connect setup, and `git init` (still zero version control). See
`RESUME.md` for the exact next steps.

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

**Turkish is the source language, not a translation.** Strings are authored in Turkish inline.
This is why `SkinType.detail` references Karadeniz, Ege and Güneydoğu rather than generic
northern European phenotype descriptions: types III and IV dominate the market.

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
