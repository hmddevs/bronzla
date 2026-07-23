# Journal

## 2026-07-20 — Bronzla scaffold and dashboard
**Intent:** Stand up the project architecture and the "Bugün" dashboard with WeatherKit.
**Outcome:** 19 source files, type-check clean under Swift 6 strict concurrency complete,
zero warnings. Domain maths isolated in `ExposureCalculator` with a written test suite.
**Blocked:** No iOS simulator runtime on this machine, so `actool` fails and nothing can be
built, run or previewed. Tests are written but unexecuted.
**Status:** ongoing

## 2026-07-20 — Skin type quiz and settings
**Intent:** Build the Fitzpatrick quiz so exposure times stop using a hardcoded type III.
**Outcome:** 7-question instrument as pure domain (`SkinTypeQuiz`) plus 10 tests, paged quiz UI
with auto-advance, result screen framing the answer as a concrete burn time at UV 8, manual
picker escape hatch, full Settings tab with disclaimer and privacy text, non-dismissable
onboarding gate. All sources type-check clean.
**Blocked:** iOS simulator runtime still downloading, so tests remain unexecuted.
**Status:** ongoing

## 2026-07-20 — First green build and test run
**Intent:** Install the iOS platform, then build and execute the suites.
**Outcome:** BUILD SUCCEEDED and TEST SUCCEEDED on iPhone 17 Pro / iOS 26.3. 40 test cases,
0 failures, 0 warnings.
**Fixed:** `LocationService` failed to compile once the real build ran: the `nonisolated`
`CLLocationManagerDelegate` bridge sent a main-actor-isolated `self` across an isolation
boundary. Replaced the delegate entirely with `CLLocationUpdate.liveUpdates`, which carries
Sendable values and needs no bridge. `swiftc -typecheck` had passed this; only a full build
runs the sendability diagnostics.
**Status:** resolved

## 2026-07-20 — Tanning timer
**Intent:** Build the session timer with flip and reapply reminders.
**Outcome:** `TimerPlan` and `TimerState` as pure value types with injected clocks,
`NotificationScheduler` scheduling all alerts up front, `TanTimerModel` handling persistence
across termination, `TimerView` with setup, running and summary states. Build green,
74 tests passing, 0 failures.
**Fixed:** `NotificationScheduler` could not be `Sendable` while storing a
`UNUserNotificationCenter`. Made it computed; the singleton is thread-safe anyway.
**Not done:** Live Activity, which needs its own widget extension target. The UI itself has no
automated coverage; only the state machine is tested.
**Status:** resolved

## 2026-07-20 — App Store readiness
**Intent:** Take the app as far as software can go towards submission.
**Outcome:** Widget extension target added by hand-written pbxproj surgery, Live Activity wired
into every timer transition, privacy manifest, export compliance and photo usage keys added,
app icon generated in three variants, full Turkish and English localisation (248 strings),
CSV export, UI test target with five end-to-end flows, APPSTORE.md submission pack.
Release build clean for both targets with zero compiler warnings, 89 unit tests passing.
**Fixed along the way:** forecast peak-window off-by-one hour; a Swift 6 main-actor isolation
warning in SessionDetailView that only the Release build surfaced; string catalogue symbol
collisions on case-differing keys; the widget failing to install because
INFOPLIST_KEY_NSExtensionPointIdentifier does not generate the nested NSExtension dictionary.
**Verified:** Clean-room Release build from an empty DerivedData is green for both targets with
zero compiler warnings. 94 test cases pass (89 unit, 5 UI end-to-end), 0 failures.
**Caught late:** a UI test asserted type IV for a score of 21, which is type V. The app was
right and the test was wrong. Also removed a doc comment on `skinType(forScore:)` claiming
boundary scores resolve towards sensitivity, which half-open intervals do not do.
**Blocked:** Team ID and WeatherKit capability. Live UV data and the Live Activity have never
run for real; both need a signed build.
**Status:** resolved

## 2026-07-20 to 2026-07-23 — Social layer, Apple Watch app, close-out
**Intent:** Add shareable stats and a competitive layer for Instagram and Snapchat, then an
Apple Watch app, then take the whole thing as far towards App Store submission as software can.
**Design call:** Score on discipline, never exposure. A tanning app that ranks hours in the sun
pays people to burn, and Türkiye has serious melanoma rates on exactly the coasts this app
targets. Clean sessions, SPF and consistency earn points; a burn costs more than any single
reward. "Sıfır yanık" is the headline on every share card, not hours accumulated. Same virality,
opposite public health effect.
**Also decided:** wordmark always on the card with no removal option (marketing for a paid app,
not a freemium watermark), and no custom backend (cards, badges and a family board need none,
and a backend would contradict the privacy promise already shipped in the App Store copy).
**2026-07-21:** Compiled and verified BronzScore, Badge, ShareCardView (written the day before,
never built). Added SocialTests (14 cases), ShareCardRenderer, InstagramSharing,
ShareCardButton, FamilyBoardView, wired into three existing screens. Added the `BronzlaWatch`
target by hand (see MEMORY.md for the pbxproj technique), sharing three domain files from the
phone target without moving them. Both compiled and embedded green; the watch app itself had
never been launched.
**2026-07-23:** Discovered mid-session that `~/Desktop` is iCloud-synced and four "missing"
component files (TimerRing, StreakCalendarView, HourlyUVChart, DailyUVRow) were actually just
offline, not absent — cost time, now documented in MEMORY.md so it doesn't repeat. Booted the
watch simulator and launched `BronzlaWatch` for the first time: confirmed stable via screenshot
and log inspection, no crash, correct Turkish permission-prompt copy; never reached the
post-permission `.loaded` state for lack of touch-injection tooling in this session. Ran the
full suite properly (140 unit + 5 UI, both explicitly verified via per-case grep — `-scheme
Bronzla` alone silently skips the UI tests). Localisation exported clean, 418 strings, 0
untranslated. Clean-room Release build of all three targets from wiped DerivedData, zero
warnings. Updated APPSTORE.md's state tables and known-limitations, though its marketing
description copy still needs a rewrite pass to mention the three features shipped this arc.
**Not done:** watch app icon, anything needing `DEVELOPMENT_TEAM` or a signed build (live
WeatherKit, Live Activity, watch WeatherKit), `git init` (still unactioned, still the largest
risk — no version control across ~7500+ lines and three build targets).
**Status:** resolved — software is feature-complete and verified; remaining work is entirely
outside code. See `RESUME.md`.
**2026-07-23 (ship readiness, second session):** Confirmed the suite green after fixing two
stale `ForecastTests` assertions still expecting Turkish after the source-language switch; they
now resolve through the same `String(localized:)` lookup the view uses, for the same reason the
suite already pins its calendar. Note the first test run appeared to fail with "Test crashed
with signal kill" on both UI tests: that was two concurrent `xcodebuild test` processes fighting
over one simulator, not a defect. One run at a time. Merged PRs #10-#13. Recovered the App Store
Connect issuer ID (it is displayed in the portal under Users and Access > Integrations, never
actually unrecoverable) and stored it with the `.p8` in `~/.appstoreconnect/`, outside the repo,
with an `asc-jwt.sh` that mints ES256 tokens using openssl alone. Filled the listing for both
`en-US` and `tr`: descriptions, keywords, promotional text, URLs, categories, age rating, review
notes. The Turkish subtitle was 31 characters against a 30 limit and would have been rejected;
"ve" became a comma. Captured the twelve phone screenshots at 1320x2868 and confirmed by reading
the rendered English forecast that it is now genuinely English. Built the first Apple Watch
screenshot set ever, which needed a DEBUG-only `WatchScreenshotSeed` because the watch reaches
WeatherKit directly and can only render an error state on a simulator. **Doing that immediately
exposed a real bug:** a Turkish watch showed "Very high", because `UVCategory.title` comes from
a shared file whose strings only ever reached the phone catalogue. Fixed, verified by rendering,
and verified again inside the Release archive's `tr.lproj/Localizable.strings`. Build 8 carried
the bug, so build 9 replaced it; both uploaded, both VALID.
**Not done:** privacy nutrition labels (portal-only, `appDataUsages` 404s), screenshot upload,
price tier, Paid Applications Agreement. Watch still never run on physical hardware, Live
Activity still never observed.
**Status:** resolved — build 9 VALID on TestFlight, listing metadata complete; what remains is
account-level and needs Umut.
**2026-07-23 (build 7 TestFlight feedback review):** Pulled all 18 TestFlight feedback
screenshots via the ASC API (`betaFeedbackScreenshotSubmissions`, requires `?include=build` to
get the build relationship — GET_COLLECTION on the resource itself 403s, must go through
`apps/{id}/betaFeedbackScreenshotSubmissions`). Only build 7 had feedback; builds 1, 2 and 6
were already addressed in earlier sessions per todo.md. Three genuine defects on build 7, traced
to root cause by reading the actual code rather than guessing from the screenshot alone:
- Session summary's OK button called `cancel()`, which `finish()` already calls internally
  right after setting `lastCompleted` — so OK could never clear it a second time. Added
  `dismissSummary()`.
- Live Activity lock-screen countdown and UV label had no explicit foreground colour, so they
  resolved `.primary` (black) against the device's actual system appearance rather than the
  card's own fixed dark tint — invisible in Light Mode. Forced white at the container level.
- `.percent` formatting follows `Locale.current`, which is Region-driven for symbol placement
  independently of the Language setting that drives words — "%0" instead of "0%" on an
  English-language, Turkish-region device. Added `Locale.app` (from
  `Bundle.main.preferredLocalizations`) and chained `.locale(.app)` onto all five `.percent`
  sites in the app.
A fourth reported item ("Data sources" not centred against the Weather wordmark) turned out, on
pixel measurement of the actual screenshot, to be a 1px difference — not a real bug. Caught this
before applying a blind "fix" that would have been pure noise. Also: writing a plain unit test
that calls `TanTimerModel.start()` crashes the test host — `ActivityKit.Activity.request` isn't
safely callable outside a real app process — so the regression test for the OK button had to be
a UI test driving a real 60-second session to completion, not a unit test.
Shipped as build 10, VALID. Full suite: 125 passed, 0 failed.
**Status:** resolved.
