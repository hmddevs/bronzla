# Bronzla

> Updated 2026-07-23. Build 1.0 (9) uploaded and VALID on TestFlight. Repo is
> `github.com/umutguden/bronzla`, `main` at the merge of PR #13. Store listing metadata is
> complete for `en-US` and `tr`. See `MEMORY.md` for the signing, Info.plist and i18n lessons,
> and `APPSTORE.md` for the submission pack.

## Done this session

- [x] App Store Connect set up end to end: Team ID in all 10 configs, 3 bundle IDs registered,
      WeatherKit enabled on phone + watch, Distribution certificate and 3 App Store profiles
      created via API, manual signing configured, app record created (`6793729675`)
- [x] Watch app icon generated; shared `.xcscheme` files written
- [x] Build 1 uploaded, internal beta group "Internal" created, umut@guden.tr invited
- [x] **English is now the source language.** 348 catalogue entries, `sourceLanguage: en`,
      0 missing a Turkish value (verified by counting absent localisations, not `state="new"`)
- [x] 101 previously-untranslated strings authored in British English
- [x] All four TestFlight defects fixed (see below)
- [x] 117 unit tests + 5 UI tests green; Release archive clean; build 2 uploaded

## The four defects from build 1 feedback

- [x] **Black sides on screen.** `INFOPLIST_KEY_UILaunchScreen_Generation` emitted a malformed
      `UILaunchScreen` nested inside itself, so iOS ran the app in 320pt compatibility mode.
      Declared properly in `Config/Bronzla-Info.plist`. Verified in the archive.
- [x] **Turkish text on English device.** The 101 untranslated strings, plus 8 hardcoded
      Turkish interpolations the catalogue could never see (duration units, VoiceOver, share
      cards, widget, Siri phrases, CSV headers, `SharedUVCategory.turkishTitle`).
- [x] **Keyboard would not dismiss** in "Add a session". Added a `@FocusState`, a Done button
      pinned above the keyboard, and `.scrollDismissesKeyboard(.interactively)`.
- [x] **"4 sa" Turkish units** (found while reviewing, not reported). Now locale-aware via
      `Duration.formatted(.units(allowed:width:))` in all 4 sites across 3 targets.

## Next

**Only Umut can do these. Nothing ships until the first two are done.**

- [ ] **Paid Applications Agreement**, with banking and tax completed. Bronzla is paid-upfront,
      so until this is active the app cannot be sold and no non-free tier can be set.
- [ ] **Price tier.** None set on the record.
- [ ] **Privacy nutrition labels.** Portal-only, confirmed: `appDataUsages`,
      `dataUsagePublishState` and `appDataUsageCategories` all return 404 PATH_ERROR. The
      answers to paste are in `APPSTORE.md` under "Privacy nutrition label answers".
- [ ] **Upload the screenshots.** Captured and ready in `build/screenshots/{en,tr}` (twelve at
      1320x2868) and `build/screenshots/watch-{en,tr}` (416x496). Needs the reservation-and-
      commit API flow or a paste into the portal.

**Verification that still needs real hardware**

- [ ] Watch app has only ever run on a simulator, never a physical Watch.
- [ ] Live Activity has still never been observed running.
- [ ] Live WeatherKit data has never been parsed by either app.

**Deliberate, revisit only if it becomes a problem**

- [ ] Place-picker region names stay Turkish (`Ege`, `Akdeniz`, `İç Anadolu`): they are
      geographic proper nouns and section headers. Revisit if English users find them opaque.
- [ ] On both phone screenshots the trailing disclaimer and WeatherKit attribution sit under
      the floating tab bar at rest. They are reachable by scrolling and the attribution
      requirement is met, but the captured shots show them clipped. Worth a look before the
      screenshots go on the listing.

## Done

- [x] **Version control.** `github.com/umutguden/bronzla`, private, default branch `main`.
      `~/.claude/hooks/pre-push-protection.sh` blocks pushing while the local branch is `main`,
      so all work goes through a PR. It is PreToolUse, so renaming and pushing in one compound
      command still trips it.
- [x] Turkish App Store listing localisation added (primary stays `en-US`).
- [x] Categories, age rating, review notes, support/marketing/privacy URLs set via the API.
- [x] `APPSTORE.md` description copy already covers social sharing, the family leaderboard and
      the watch app; both locales verified against the field limits before upload.
- [x] Apple Watch screenshot set captured for the first time, which exposed and fixed a real
      Turkish localisation bug in the watch UV category.

## Deliberately excluded, do not add

Exposure-ranked leaderboards, "darkest tan" rankings, streak guilt-tripping. They reward
staying out longer, which inverts a sun-safety app's purpose.
