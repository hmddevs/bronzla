# Bronzla

Bronzla tells you how long you can safely stay in the sun, based on your skin type and the
live UV index. It is a free iOS and watchOS app, built for Türkiye first.

No account. No ads. No subscription. No in-app purchases. No analytics SDKs.

[Download on the App Store](https://apps.apple.com/app/id6793729675) · [bronzla.app](https://bronzla.app)

## Safety notice

Bronzla is not a medical device and does not give medical advice. It estimates sun exposure
limits from published dermatological guidance and a live UV index, and those estimates carry
real uncertainty. No app can tell you that a given exposure is safe for you specifically.
People with photosensitivity, a history of skin cancer, or medication that affects UV
sensitivity should speak to a doctor rather than rely on this.

Every constant in the exposure model traces to a published source. Those sources are listed
in [docs/EXPOSURE-MODEL.md](docs/EXPOSURE-MODEL.md) and are reachable from inside the app on
every screen that gives guidance. Where a figure is the app's own estimate rather than
published data, it says so, in the code and in the interface.

## What it does

- A sun timer driven by your Fitzpatrick skin type, the current UV index and your sunscreen
  SPF, with flip and reapplication reminders.
- Hourly and ten day UV forecasts, charted.
- Session history and a discipline score that rewards staying inside safe limits rather than
  maximising time in the sun.
- Family profiles, so one phone can track several people.
- An Apple Watch app, home screen widgets and a Live Activity.
- Full Turkish and English localisation. Turkish is the source language.

## Repository layout

```
App/          Xcode project and all five targets
              Bronzla, BronzlaWatch, BronzlaWidgets, BronzlaTests, BronzlaUITests,
              plus Shared/ and Config/
backend/      AWS CDK stack for Sign in with Apple and the global leaderboard
site/         bronzla.app, an Astro static site deployed to Cloudflare
docs/         Architecture and the exposure model
tools/        Standalone developer utilities
```

The Xcode project lives inside `App/` alongside every folder it references, so all paths in
`project.pbxproj` are relative and the project can be moved as a unit.

## Building

Requires Xcode 26 or later, and an iOS 18.0 or later simulator runtime.

```
cd App
xcodebuild build -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Tests:

```
cd App
xcodebuild test -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The unit suite is 129 tests across 14 suites, written with Swift Testing. Note that
`xcodebuild` prints `Executed 0 tests` from its legacy XCTest reporter, because there are no
XCTest cases; read the Swift Testing summary instead.

WeatherKit will not return data in a fork without your own Apple Developer team and a
WeatherKit-enabled App ID. The app is built so this does not block you: every weather-backed
service is behind a protocol with a sample implementation, so previews, tests and offline use
all work without a WeatherKit entitlement. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Backend status

The CDK stack in `backend/` is complete and unit-tested, but the shipped 1.0 build points at a
placeholder URL, so **the global leaderboard is inert in the released app**. Everything else,
including the on-device family leaderboard, works fully offline. This is stated plainly rather
than glossed, because a repository that implies a running service it does not have is worse
than one that admits the gap.

## Privacy

Location never leaves the device. Coordinates are rounded to two decimal places before being
used as a cache key, which is roughly a kilometre of precision, enough to cache a UV forecast
and not enough to identify a home address. Sign in with Apple is optional and gates only the
global leaderboard. Session tokens are stored in the Keychain, scoped to one device, never in
`UserDefaults`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: changes to `ExposureCalculator`
need a cited source and a test, because that is the code that can burn someone.

To report a security issue, see [SECURITY.md](SECURITY.md). Please do not open a public issue
for anything security related.

## Licence

Licensed under the Apache Licence, Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

"Bronzla" and the app icon are trademarks of HMD Developments and are not covered by that
licence. You may fork and redistribute the source, but not under the Bronzla name or icon.

Built by Umut Güden, on behalf of HMD Developments.
