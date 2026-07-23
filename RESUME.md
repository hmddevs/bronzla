# RESUME HERE

Handover for the next session. Written 2026-07-23. Software is done; what's left is entirely
outside code. Read `tasks/todo.md` for the full checklist and `MEMORY.md` for architecture
rationale, especially the new iCloud section below — it will save real time.

---

## State in one line

All three targets (`Bronzla`, `BronzlaWidgets`, `BronzlaWatch`) build clean in Release from
wiped DerivedData, zero compiler warnings. 140 unit tests and 5 UI tests all pass. Localisation
is complete. The watch app installs, launches and renders stably on a simulator. Nothing is
committed; there is still no git repo.

---

## Read this before touching any file: Desktop is iCloud-synced

`~/Desktop/TanApp` syncs through iCloud Drive. Some source files can be genuinely absent from
local disk while still existing in the cloud, and can materialize mid-session with **no
warning**, days after they were written. This session hit "cannot find 'TimerRing' in scope"
on a clean build, with `find`/`ls` showing the containing folder completely empty — the natural
conclusion was "these files were never written." That conclusion was wrong four times over
(`TimerRing.swift`, `StreakCalendarView.swift`, `HourlyUVChart.swift`, `DailyUVRow.swift` all
turned out to exist already, correctly, dated 2026-07-20).

**Before concluding any file or folder is genuinely missing: run `brctl download <path>` on the
project root and wait 10-15 seconds, then recheck.** If you write a replacement file and a
`"<name> 2.swift"` appears afterwards, that " 2" file is very likely the real, pre-existing
original that just finished downloading — diff before deciding which to keep, don't assume your
new file is right. Full account in `MEMORY.md` under "Desktop is iCloud-synced".

---

## What's actually left

### 1. Watch app: reach the `.loaded` state (nice to have, not blocking)

The watch app is confirmed stable through the system location-permission prompt but was never
tapped through, because `simctl` has no touch-injection command for watchOS and an
`osascript`/System Events attempt to drive the Simulator window hung waiting on a macOS
Accessibility permission this session couldn't grant interactively. If you have interactive
access to the machine (or that Accessibility grant is already in place), boot the same
simulator and tap "Allow" to confirm `WatchUVModel.refresh()` runs past the gate:

```
xcrun simctl boot "Apple Watch Series 11 (46mm)"   # or whichever UDID is free
# install BronzlaWatch.app from DerivedData, launch com.hmdcorp.bronzla.watch, tap Allow
```

**Do not use `xcrun simctl erase`** — it is blocked by this machine's `guardrail.py` hook as a
destructive power-state change, and rightly so; use `simctl uninstall`/`install` on the one app
if a clean permission state is needed again.

**Known gap, not urgent:** no watch app icon (`Assets.xcassets`) exists yet. Fine for the
simulator; blocks an eventual archive.

### 2. APPSTORE.md description copy

The feature/test/limitations tables are updated and accurate, but the Turkish and English
marketing description text still doesn't mention social sharing, the family leaderboard or the
watch app. This needs a proper copy pass, not a bolted-on bullet — flagged in the file itself
under Known limitations.

### 3. Suggest `git init` to Umut

Still the single largest remaining risk: three build targets, roughly 7500+ lines, and zero
version control. Do not init or commit without his explicit word.

### 4. Blocked on Umut's Apple Developer account (unchanged, cannot be actioned here)

- `DEVELOPMENT_TEAM` empty in every configuration, including the watch target
- WeatherKit capability needed on **both** App IDs: `com.hmdcorp.bronzla` and
  `com.hmdcorp.bronzla.watch`
- Live WeatherKit and the Live Activity have never been verified against a real response —
  needs a signed build on a device
- Watch app icon, archive, upload, App Store Connect listing, screenshots

---

## What changed this session (for context, not action)

- Discovered and documented the iCloud sync hazard above — cost real time at the start of this
  session and will cost more for whoever doesn't read it first.
- Restored four files (`TimerRing.swift`, `StreakCalendarView.swift`, `HourlyUVChart.swift`,
  `DailyUVRow.swift`) that appeared to be missing but were genuinely just offline; verified by
  diffing against the reimplementations this session initially wrote before understanding what
  was happening, and keeping the pre-existing, more complete originals.
- Booted the watch simulator, installed, and launched `BronzlaWatch` for the first time ever.
  Confirmed alive and stable via screenshot (correct Turkish permission-prompt copy) and
  `log show` (no crash/fault/fatal entries).
- Ran the full unit suite (140 cases) and, separately with `-only-testing:BronzlaUITests`, the
  UI suite (5 cases) — both green, verified with per-case grep, not the bare exit code.
- Ran `-exportLocalizations`: 418 translation units, 0 untranslated.
- Wiped DerivedData and ran clean-room Release builds of all three schemes (`Bronzla`,
  `BronzlaWidgets`, `BronzlaWatch`); zero Swift compiler warnings in any of them.
- Updated `APPSTORE.md`'s state table, nutrition-label answers and known-limitations section for
  social sharing, the family leaderboard, the watch app and the `LSApplicationQueriesSchemes`
  disclosure. Description copy itself still needs a rewrite pass (see above).
- Checked the previously-flagged `SettingsView` orphaned `protectionSection` — it's already
  gone; someone removed it in an earlier session without updating `todo.md`.

---

## Known issues, carried forward

- **`DEVELOPMENT_TEAM` is empty** in every configuration, including the watch target. Blocks
  WeatherKit, Live Activity, and archiving on all three targets. Only Umut can supply it.
- **Live WeatherKit has never parsed a real response**, on phone or watch. Debug builds fall
  back to `SampleUVProvider`, labelled "Örnek veri gösteriliyor" on screen.
- **The Live Activity has never been observed running.** Needs a signed build on a device.
- **The watch app has been launched and observed on simulator only** — see item 1 above.
- **Adding a non-optional field to a SwiftData `@Model` needs the default declared inline on
  the property**, not only in `init`. Otherwise it compiles and then crashes on any device with
  an existing store. This already bit once.
- **Stale simulator SwiftData stores** cause false test failures after a schema change. Fix with
  `xcrun simctl uninstall "iPhone 17 Pro" com.hmdcorp.bronzla`.
- **Array/dictionary Info.plist keys never survive `INFOPLIST_KEY_`.** Always use a partial
  `.plist` file + `INFOPLIST_FILE` instead. Two confirmed instances: the widget's `NSExtension`
  dict, and `LSApplicationQueriesSchemes`.
- **`-scheme Bronzla` alone does not run `BronzlaUITests`.** It builds the target but executes
  zero UI test cases. Use `-only-testing:BronzlaUITests` explicitly, and always verify with
  `grep "Test case.*passed"`, never the bare `** TEST SUCCEEDED **` line.
- **Desktop is iCloud-synced; files can be offline and appear missing.** See the section above
  and `MEMORY.md`. This is the newest and most likely lesson to bite the next session too.

---

## Deliberately excluded, do not add

Social sharing of raw exposure, "darkest tan" rankings, leaderboards ranked on hours, and streak
guilt-tripping. On a sun-safety app these reward staying out longer, which inverts the product's
purpose, and Türkiye has serious melanoma rates on exactly the coasts this app targets. If asked
to add them, say so before building.
