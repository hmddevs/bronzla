# Bronzla

Paid-upfront iOS app for safe sun exposure and tanning, Turkish market first.
One-time purchase, no ads, no IAP, no subscriptions, no analytics SDKs.

## Stack
- SwiftUI only, iOS 18.0 minimum, Swift 6 with `-strict-concurrency=complete`.
- `@Observable` for state. SwiftData for persistence. Swift Charts for forecasts.
- WeatherKit for UV, CoreLocation for position, Swift Testing for tests.
- Bundle ID `com.hmdcorp.bronzla`. Development region `tr`.

## Project layout
Xcode 26 synchronised folder groups (`PBXFileSystemSynchronizedRootGroup`): any file added
under `Bronzla/` or `BronzlaTests/` joins the target automatically. Never hand-edit
`project.pbxproj` to register a file. Entitlements live in `Config/`, deliberately outside
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
- `MedicalDisclaimer` appears on every screen that gives exposure guidance.
- WeatherKit attribution (`WeatherAttributionView`) appears on every screen showing its data.
  Omitting it is an App Review rejection.
- Never widen the privacy surface. Location stays on device; coordinates are rounded to two
  decimal places before being used as a cache key.

## Verification
```
xcodebuild build -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Type-check without the asset catalog step (useful when no simulator runtime is installed):
```
xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios18.0 -swift-version 6 -strict-concurrency=complete \
  $(find Bronzla -name '*.swift')
```
