# Architecture

Bronzla is a free iOS and watchOS app for safe sun exposure, written for the Turkish market
first. This document is for someone reading the repository for the first time: what the pieces
are, why they are shaped the way they are, and where to put new code.

The scientific model behind the exposure numbers is documented separately in
[EXPOSURE-MODEL.md](EXPOSURE-MODEL.md). Read that before touching anything under
`App/Bronzla/Services/Exposure/`.

## Repository layout

```
App/                      Xcode project and all Swift code
  Bronzla.xcodeproj/      Single project, five targets
  Bronzla/                iOS app
    App/                  Entry point, tab shell, screenshot seeding
    DesignSystem/         MedicalDisclaimer, Palette
    Features/             One folder per screen or feature area
    Models/               Domain types and SwiftData models
    Services/             Weather, Location, Leaderboard, Health, Photos,
                          Notifications, Live Activity, Intents, Export, Exposure
    Resources/            Assets, Localizable.xcstrings
  BronzlaWatch/           watchOS app
  BronzlaWidgets/         Widget extension and Live Activity
  BronzlaTests/           Swift Testing unit tests
  BronzlaUITests/         XCUITest flows and App Store screenshot capture
  Shared/                 Types shared between app, widget and watch
  Config/                 Info.plist and .entitlements files, deliberately
                          outside the synchronised folders
backend/                  AWS CDK stack, four Lambdas, DynamoDB (not deployed)
site/                     Astro marketing site
tools/                    One-off developer scripts (app icon generation)
docs/                     This directory
```

## Targets

| Target | Type | What it does |
| --- | --- | --- |
| `Bronzla` | iOS application | The app itself. Six tabs: Today, Forecast, Timer, Tracker, Leaderboard, Settings. |
| `BronzlaWatch` | watchOS application | Standalone watch app showing the current UV index and the recommended session for the active profile. Has its own WeatherKit entitlement and its own attribution view. |
| `BronzlaWidgets` | App extension | Home screen UV widget plus the `TanSession` Live Activity shown while a timer runs. Shares data with the app through an app group. |
| `BronzlaTests` | Unit test bundle | Swift Testing. Covers the exposure maths, score, quiz, forecast, insights, aftercare, timer state and the leaderboard service. |
| `BronzlaUITests` | UI test bundle | End-to-end flows, and the deterministic App Store screenshot run. |

Minimum deployment target is iOS 18.0. The language mode is Swift 6 with
`-strict-concurrency=complete`, so every type crossing an isolation boundary is `Sendable` and
the compiler, not review, enforces it.

## Synchronised folder groups

The project uses Xcode 26 `PBXFileSystemSynchronizedRootGroup` entries. Each target has one
root folder on disk (`App/Bronzla`, `App/BronzlaWatch`, and so on), and every file inside that
folder is a member of the target automatically.

The practical consequences:

- To add a file, create it in the right folder. That is the whole procedure.
- Never hand-edit `project.pbxproj` to register a file. There is nothing to register, and an
  edit there will either be ignored or will corrupt the synchronised group.
- Deleting a file from disk removes it from the target. There is no stale reference to clean up.
- `Config/` sits outside the synchronised folders on purpose. If the `.entitlements` and
  `Info.plist` files lived inside `Bronzla/`, they would be copied into the app bundle as
  resources rather than consumed by the build settings.

`Shared/` is referenced by the app, watch and widget targets, so a type placed there is visible
to all three.

## Service pattern: protocols first

Every service that reaches outside the process is defined as a protocol, with a live
implementation and a deterministic sample implementation. Services are injected through the
SwiftUI environment in `BronzlaApp.swift`, never constructed at the point of use.

This is not testing purism. It exists because the live dependencies genuinely are not available
in three situations the project has to work in every day.

### `UVDataProviding`

`App/Bronzla/Services/Weather/UVDataProviding.swift`

```swift
func report(for coordinate: CLLocationCoordinate2D, placeName: String) async throws -> UVReport
```

| Implementation | Used by | Notes |
| --- | --- | --- |
| `WeatherKitUVProvider` | Shipping app, watch app | Apple WeatherKit. Requires the `com.apple.developer.weatherkit` entitlement and an App ID with the capability enabled. |
| `SampleUVProvider` | Previews, unit tests, unsigned simulator builds | Models a realistic daily UV curve rather than returning random values, so previews are stable across redraws and a screenshot taken today matches one taken tomorrow. Has an injectable `failure` so error states can be designed without unplugging the network. |
| `ScreenshotUVProvider` | App Store screenshot runs only | Compiled behind `#if DEBUG`, so no shipping build can be talked into serving fabricated readings by a launch argument. |

The three reasons the protocol exists, in the order they bite:

1. **WeatherKit is absent in SwiftUI previews.** Previews have no entitlement, so a view built
   directly against `WeatherService` cannot be previewed at all.
2. **WeatherKit is absent offline.** People use this app on beaches. The cache sits behind the
   protocol, so callers never branch on where the data came from; they read `UVReport.source`
   only when they want to tell the user how fresh it is.
3. **WeatherKit is metered at 500,000 calls per month.** Every avoidable call in development,
   in tests and in previews is real quota. The sample provider costs nothing.

`UVReportCache` sits behind `WeatherKitUVProvider` as an actor. It stores at most eight reports
on disk and discards anything older than twelve hours, on the grounds that a day-old reading is
worse than none because it will disagree with the sky overhead.

### `LeaderboardServiceProviding`

`App/Bronzla/Services/Leaderboard/LeaderboardServiceProviding.swift`

Five operations: `signIn(identityToken:displayName:)`, `submitScore(_:displayName:)`,
`fetchLeaderboard(limit:)`, `deleteAccount()` and `signOut()`, plus `currentSession()`.

| Implementation | Used by | Notes |
| --- | --- | --- |
| `LiveLeaderboardService` | Shipping app | A thin `URLSession` and `Codable` client over four endpoints. No networking library for four routes. `baseURL` is injectable. Session tokens are held in the Keychain by `KeychainSessionStore`. |
| `SampleLeaderboardProvider` | Previews, unit tests | Fixed entries and an injectable `failure`, mirroring `SampleUVProvider`'s shape. |

The same reasoning applies: there is no backend in a preview, a unit test or an unsigned
simulator build, so call sites are written against the protocol.

`deleteAccount()` is not optional politeness. Apple Guideline 5.1.1(v) requires an in-app
account deletion path for any app offering account creation, and Sign in with Apple counts.

### Scoring

`BronzScore` (`App/Bronzla/Features/Social/BronzScore.swift`) is pure and dependency-free, like
`ExposureCalculator`. It deliberately rewards discipline rather than exposure: clean sessions,
sunscreen worn, day streaks, with a burn penalty larger than any single reward. A leaderboard
ranked on hours in the sun would pay people to burn, which is the wrong incentive to ship on
the Mediterranean coast.

## Persistence

SwiftData, with two `@Model` types:

- `UserProfile`: skin type, default SPF, exposed body fraction, onboarding state, plus the
  multi-profile fields (name, active flag, colour) for families sharing a device.
- `TanSession`: start and end, place name, SPF, skin type at the time, accumulated erythemal
  dose, peak UV index, notes, photo file names, and an optional link back to a profile.

The `ModelContainer` is built in `BronzlaApp.swift`. If the store will not open, the app calls
`fatalError` rather than falling back to an in-memory container, because a silent fallback would
quietly discard the user's history and look like a bug in the tracker.

Session photographs are not stored in SwiftData. `SessionPhotoStore` writes them to the file
system and the model holds file names.

Everything else that is not a session (preferences, the active profile) lives in
`UserDefaults` through small stores such as `ActiveProfileStore`.

## Privacy model

The app's privacy claim is simple: location never leaves the device.

- CoreLocation fixes are consumed in-process by `LocationService` and handed to WeatherKit,
  which is an Apple framework call, not a Bronzla server call.
- Before a coordinate is used as a cache key it is rounded to two decimal places, roughly one
  kilometre. UV does not vary meaningfully over that distance, walking along a beach still hits
  the cache, and the cache file on disk records substantially less about where someone has been
  than the raw fix would.
- Error logging is split deliberately. Error domain, code and type are logged `.public` because
  they identify the failure and carry nothing about the user. Free-text error descriptions are
  logged `.private`, because a WeatherKit or CoreLocation error can embed the request URL, and
  that URL contains the coordinates. `.private` is redacted in sysdiagnose collection while
  still readable on an attached device during development.
- There are no analytics SDKs, no advertising identifiers and no third-party trackers.
- The only data that ever reaches a Bronzla-operated server, once one exists, is a display name
  the person typed and chose to submit, plus a numeric score. Apple's one-time name grant is
  prefilled but editable before it is sent, and the server never receives a real name or email.
- `MedicalDisclaimer` appears on every screen that gives exposure guidance and is itself the tap
  target for the citation list. `WeatherAttributionView` appears on every screen showing
  WeatherKit data. Both are requirements, not decoration: the first satisfies App Review
  guideline 1.4.1, the second is a condition of using WeatherKit.

## Backend, and its actual status

`backend/` is an AWS CDK application defining one stack, `BronzlaBackendStack-dev`:

- **Three DynamoDB tables**, all `PAY_PER_REQUEST`: `BronzlaUsers-dev`, `BronzlaSessions-dev`
  (TTL on `expiresAt`, plus a `SessionsByAppleSub` KEYS_ONLY GSI so account deletion can find a
  user's sessions without scanning), and `BronzlaScores-dev` (a `LeaderboardByScope` GSI with a
  constant partition key and a zero-padded, inverted score sort key, so one ascending query
  returns the top scores with no table scan).
- **Four Node.js 20 Lambdas** behind an API Gateway HTTP API, each with least-privilege IAM
  scoped to only the tables and indexes it touches:

| Route | Handler | Behaviour |
| --- | --- | --- |
| `POST /auth/apple` | `auth-apple.ts` | Verifies an Apple identity token against Apple's JWKS, upserts the user, issues a session token. |
| `PUT /score` | `put-score.ts` | Authenticated. Upserts the caller's score. |
| `GET /leaderboard` | `get-leaderboard.ts` | Authenticated. Returns the top N entries as `displayName` and `score` only, never `appleSub`. |
| `DELETE /account` | `delete-account.ts` | Authenticated. Deletes the user, their score and every session, transactionally. |

**Status: built and unit-tested, but not deployed, and therefore inert in version 1.0.**

Be clear about what that means. `npx cdk synth` renders the template and `npm test` runs the
vitest suite offline, including Apple token verification against a locally generated keypair
with a mocked JWKS fetch, the score sort-key encoding, and all three authenticated handlers
against a mocked DynamoDB client. Neither `cdk bootstrap` nor `cdk deploy` has been run against
any AWS account. No infrastructure exists.

Consequently the global leaderboard does not function in the 1.0 App Store release. The client
code is present, `LiveLeaderboardService` is wired into the environment, and the Leaderboard tab
renders, but the only board with real content is the local, on-device family board. Any global
leaderboard call fails at the network layer and surfaces as an error state. This is a known and
accepted state for 1.0, not an outage.

Deployment is blocked on a deliberate human decision about which AWS account owns this product;
see `backend/README.md`.

## Where do I add X

| Task | Where |
| --- | --- |
| A new screen | `App/Bronzla/Features/<Feature>/`. Views stay small and dumb. Add a `Model` type only when the screen coordinates async work or owns a failure state; otherwise read services straight from the environment. |
| A reusable component for one feature | `App/Bronzla/Features/<Feature>/Components/`. |
| A component used by several features | `App/Bronzla/DesignSystem/`. |
| A new external dependency (network, sensor, system framework) | `App/Bronzla/Services/<Area>/`. Define the protocol first, then a live implementation and a sample implementation, then inject it through the environment in `BronzlaApp.swift`. |
| Domain maths | A pure `enum` with static methods and no dependencies, under `Services/` or `Models/`, with tests. |
| A new persisted field | The relevant `@Model` in `App/Bronzla/Models/`. Consider SwiftData migration if the property is not optional and has no default. |
| A type the widget or watch also needs | `App/Shared/`. |
| A UI string | Write it in Turkish inline, then extract to `Localizable.xcstrings`. Turkish is the source language; English is the translation, not the other way round. |
| A change to exposure maths | `App/Bronzla/Services/Exposure/ExposureCalculator.swift`, with a citation and a test. Read [EXPOSURE-MODEL.md](EXPOSURE-MODEL.md) first. |
| A new citation | `MedicalSource.all` in `App/Bronzla/Models/MedicalSource.swift`. It is the single canonical catalogue and `MedicalSourcesView` renders it. |
| A backend route | `backend/lambda/`, wired in `backend/lib/bronzla-backend-stack.ts`, with a vitest test in `backend/test/`. |

## Verification

```
xcodebuild build -project App/Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project App/Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Backend:

```
cd backend && npm install && npx cdk synth && npm test
```

Both `cdk synth` and the test suite run entirely offline and need no AWS credentials.
