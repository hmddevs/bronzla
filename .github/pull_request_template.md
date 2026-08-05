**What this changes**

**Why**

**Checklist**
- [ ] `xcodebuild build` and `xcodebuild test` pass locally (read the Swift Testing summary, not `Executed 0 tests`)
- [ ] British English, no em dashes
- [ ] If this touches `ExposureCalculator`, `SkinType` or the MED table: every changed constant traces to a published source, that source has an entry in `MedicalSource.swift` so it is reachable in-app, and there are tests
- [ ] `MedicalDisclaimer` still present on every guidance screen
- [ ] `WeatherAttributionView` still present on every screen showing WeatherKit data
