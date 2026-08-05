# Contributing to Bronzla

Contributions are welcome. This document covers the things that are specific to this project;
everything else is ordinary good practice.

## The one rule that matters

`App/Bronzla/Services/Exposure/ExposureCalculator.swift` is a trust boundary. It decides how
long the app tells a person they can stay in the sun. Get it wrong and someone gets burned.

Any change to that file, to `SkinType.swift`, or to the MED table must:

1. Trace every changed constant to a published, citable source.
2. Add or update an entry in `App/Bronzla/Models/MedicalSource.swift`, so the citation is
   reachable from inside the app, not just from a code comment. Apple rejected an earlier
   build under guideline 1.4.1 for exactly this: sources existed in comments but users could
   not see them.
3. Come with tests.

If a figure is our own estimate rather than published data, label it as an estimate in both
the code and the user-facing copy. The vitamin D melanin multipliers are an existing example.

Before filing a bug against the MED values, please read the units section of
[docs/EXPOSURE-MODEL.md](docs/EXPOSURE-MODEL.md). The table is in erythemally weighted J/m²,
which is not comparable to the unweighted mJ/cm² figures reported by solar-simulator studies.
That mismatch has already produced one false report.

## Compliance invariants

These are not stylistic. Breaking one is an App Store rejection:

- `MedicalDisclaimer` appears on every screen that gives exposure guidance.
- `WeatherAttributionView` appears on every screen that displays WeatherKit data. Apple
  requires the attribution.
- Coordinates are rounded to two decimal places before being used as a cache key. Never widen
  the privacy surface.

## Project conventions

- SwiftUI only. iOS 18.0 minimum. Swift 6 with `-strict-concurrency=complete`.
- `@Observable` for state, SwiftData for persistence, Swift Charts for forecasts.
- Views are small and unopinionated. A screen gets a `Model` only when it coordinates async
  work or owns a failure state. Otherwise it reads services from the environment.
- Services are protocols first, for example `UVDataProviding` and `LeaderboardServiceProviding`.
  This is not architecture for its own sake: WeatherKit is absent in previews, absent offline
  and metered at 500k calls per month, so a sample implementation is a practical requirement.
- Domain maths lives in pure enums with static methods, no dependencies, fully tested.
- Turkish is the source language. UI strings are written in Turkish and extracted to
  `Localizable.xcstrings`. English is the translation, not the other way round.
- British English in code comments, commit messages and documentation.
- No em dashes anywhere, including comments.

### Xcode project files

The project uses Xcode 26 synchronised folder groups. Any file added under a target's folder
joins that target automatically. **Never hand-edit `project.pbxproj` to register a file.**
Entitlements live in `App/Config/`, deliberately outside the synchronised folders so they are
not copied in as resources.

## Before you open a pull request

```
cd App
xcodebuild build -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

For the backend:

```
cd backend
npm install && npm test
```

Read the Swift Testing summary, not the `Executed 0 tests` line from the legacy XCTest
reporter.

## Commits and pull requests

- Imperative mood, 72 character subject limit, British English.
- One concern per commit. One feature per pull request.
- Branch names as `kind/short-kebab`, for example `fix/timer-attribution`.

## Known open items

Worth knowing before you pick something up:

- Seven `BronzlaUITests` failures around the onboarding wizard, pre-existing.
- The backend is not deployed, so the global leaderboard is inert in the shipped app.
