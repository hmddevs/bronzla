# Bronzla

> Updated 2026-07-23. Build 2 uploaded to TestFlight with all four reported defects fixed.
> Snapshot from before the i18n refactor: `~/bronzla-pre-i18n-refactor-20260723-0338.tar.gz`.
> There is still **no git repo**. See `MEMORY.md` for the signing, Info.plist and i18n lessons.

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

- [ ] Confirm build 2 installs and the four fixes hold on the device, especially the black bars
- [ ] **Suggest `git init` to Umut.** Now well past 7500 lines, three targets, an App Store
      record and a signing setup, with zero version control. Single largest remaining risk.
      Do not init or commit without his explicit word.
- [ ] Add the Turkish App Store listing localisation (primary stays `en-US` per Umut)
- [ ] Rewrite `APPSTORE.md`'s Turkish/English description copy: it still does not mention
      social sharing, the family leaderboard or the watch app
- [ ] Watch app has still only ever run on a simulator, never a physical Watch
- [ ] Live Activity has still never been observed running
- [ ] Place-picker region names are still Turkish (`Ege`, `Akdeniz`, `İç Anadolu`). Deliberate
      for now: they are geographic proper nouns and section headers. Revisit if English users
      find them opaque.

## Deliberately excluded, do not add

Exposure-ranked leaderboards, "darkest tan" rankings, streak guilt-tripping. They reward
staying out longer, which inverts a sun-safety app's purpose.
