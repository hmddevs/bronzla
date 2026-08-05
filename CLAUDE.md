# Bronzla

Free iOS and watchOS app for safe sun exposure and tanning, Turkish market first.
No ads, no IAP, no subscriptions, no analytics SDKs. Open source under Apache 2.0.

## Stack
- SwiftUI only, iOS 18.0 minimum, Swift 6 with `-strict-concurrency=complete`.
- `@Observable` for state. SwiftData for persistence. Swift Charts for forecasts.
- WeatherKit for UV, CoreLocation for position, Swift Testing for tests.
- Bundle ID `com.hmdcorp.bronzla`. Development region `tr`.

## Repository layout
```
App/       Xcode project and all five targets, plus Shared/ and Config/
backend/   AWS CDK stack, Sign in with Apple and the leaderboard
site/      bronzla.app, Astro, deployed to Cloudflare
docs/      Public architecture and exposure-model documentation
tools/     Standalone developer utilities
.internal/ Working notes, gitignored, never published
```

The `.xcodeproj` sits inside `App/` alongside every folder it references, so all
`project.pbxproj` paths are relative and the whole project moves as a unit.

## Project structure
Xcode 26 synchronised folder groups (`PBXFileSystemSynchronizedRootGroup`): any file added
under `App/Bronzla/` or `App/BronzlaTests/` joins the target automatically. Never hand-edit
`project.pbxproj` to register a file. Entitlements live in `App/Config/`, deliberately outside
the synchronised folder so they are not copied in as a resource.

## Conventions
- Views are small and dumb. A screen gets a `Model` only when it coordinates async work or
  owns a failure state; otherwise it reads services from the environment directly.
- Services are protocols first (`UVDataProviding`), because WeatherKit is absent in previews,
  absent offline and metered at 500k calls/month.
- Domain maths lives in pure enums with static methods, no dependencies, fully tested.
- Turkish is the source language. UI strings are written in Turkish inline and extracted to
  `Localizable.xcstrings`; English is the translation, not the other way round.
- British English in code comments, commit messages and all documentation.
- No em dashes anywhere, including comments.

## Non-negotiables
- `ExposureCalculator` is the trust boundary. Every constant traces to a published source and
  every change needs a test. This is the code that can burn someone.
- A cited constant must also appear in `MedicalSource.swift`, so users can reach the citation
  in-app. Apple rejected build 10 under guideline 1.4.1 for citations that existed only in
  code comments.
- `MedicalDisclaimer` appears on every screen that gives exposure guidance.
- WeatherKit attribution (`WeatherAttributionView`) appears on every screen showing its data.
  Omitting it is an App Review rejection.
- Never widen the privacy surface. Location stays on device; coordinates are rounded to two
  decimal places before being used as a cache key.

## Verification
```
cd App
xcodebuild build -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Read the Swift Testing summary, not `Executed 0 tests` from the legacy XCTest reporter: the
suite is 129 tests across 14 suites and contains no XCTest cases.

Backend: `cd backend && npm install && npm test` (54 tests across 8 files).

Type-check without the asset catalog step (useful when no simulator runtime is installed):
```
xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios18.0 -swift-version 6 -strict-concurrency=complete \
  $(find App/Bronzla -name '*.swift')
```

## Known open items
- Seven `BronzlaUITests` failures around the onboarding wizard, pre-existing.
- `TimerView` shows a UV index without `WeatherAttributionView`. Compliance gap, fix in 1.0.1.
- Backend is not deployed; the global leaderboard is inert in the shipped build.
- Build 12 shipped with automatic signing via the ASC API key. Manual signing could not
  resolve profiles; do not assume it works.
