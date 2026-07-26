# Bronzla — App Store submission pack

Everything below is ready to paste. The three items under "Only you can do this" require your
Apple Developer account and cannot be completed from code.

---

## Only you can do this

All four items here are now **done** (2026-07-23), via the App Store Connect API plus two
portal-only steps Apple exposes no API for. Kept for the record:

1. ~~**Team ID.**~~ `DEVELOPMENT_TEAM = LC326A2F4F` is set in all 10 configurations.
2. ~~**WeatherKit capability.**~~ Enabled on both App IDs (`com.hmdcorp.bronzla`,
   `com.hmdcorp.bronzla.watch`). The capability toggle has no API and was done in the portal.
3. ~~**Watch app icon.**~~ Generated from `Tools/GenerateAppIcon.swift` into
   `BronzlaWatch/Assets.xcassets`. Note `CFBundleIconName` needs a partial plist
   (`Config/BronzlaWatch-Info.plist`); `INFOPLIST_KEY_CFBundleIconName` is silently ignored.
4. ~~**App Store Connect record.**~~ Created (app id `6793729675`, primary locale `en-US`).
   App record creation has no API either.

Signing is manual, not automatic: automatic signing kept requesting Development profiles in a
headless session. An `Apple Distribution` certificate and three `IOS_APP_STORE` profiles were
created via the API and are referenced by `PROVISIONING_PROFILE_SPECIFIER` per target. Note the
watch target's specifier must NOT be scoped `[sdk=iphoneos*]`, since it builds for watchOS.

Done on 2026-07-23 via the API, once the issuer ID was recovered (it is displayed in App Store
Connect under Users and Access > Integrations > App Store Connect API; it was never
unrecoverable, only unrecorded). It now lives in `~/.appstoreconnect/bronzla.env`, outside the
repo, alongside the `.p8` and a `asc-jwt.sh` that mints a token with openssl alone:

5. ~~**Turkish listing localisation.**~~ Both `en-US` and `tr` now carry name, subtitle,
   description, keywords, promotional text, and support, marketing and privacy URLs.
6. ~~**Categories.**~~ Primary Health & Fitness, secondary Weather.
7. ~~**Age rating.**~~ Declared. The API rejects a partial declaration: it requires the newer
   capability fields (`advertising`, `ageAssurance`, `gunsOrOtherWeapons`, `healthOrWellnessTopics`,
   `lootBox`, `messagingAndChat`, `parentalControls`, `userGeneratedContent`) even though
   secondary sources still describe them as portal-only. `healthOrWellnessTopics` is declared
   **true**, which APPSTORE.md's older answer set predates: for an app whose whole subject is
   sun-safety guidance, false would understate it.
8. ~~**App Review notes.**~~ Set from the text below.

Still outstanding for a public release, and none of it can be done from code:

9. **Price tier.** Set the app to free in App Store Connect. There is no purchase price to
   configure, but the record still needs the live submission wiring finished.
10. **Privacy nutrition labels.** Portal-only, confirmed empirically: `appDataUsages`,
    `dataUsagePublishState` and `appDataUsageCategories` all return 404 PATH_ERROR. The answers
    to paste are in "Privacy nutrition label answers" below.
11. **Screenshot upload.** The PNGs are captured (see Screenshots) but uploading them needs the
    reservation-and-commit flow, or a paste into the portal.
12. **App Group** must be re-attached in the portal if the App ID is ever recreated (no API).

Archive command once signing is configured:

```
xcodebuild -project Bronzla.xcodeproj -scheme Bronzla -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Bronzla.xcarchive archive
```

---

## Software readiness

| Item | State |
|---|---|
| Release build, app + widget + watch, from wiped DerivedData | green, zero compiler warnings |
| Unit tests | 117 passing, 0 failing (Swift Testing) |
| UI tests | 5 flows, all passing, see `BronzlaUITests` |
| Watch app | builds, installs, launches and renders on the Apple Watch Series 11 (46mm)
  simulator without crashing. Never run on a physical device. |
| Privacy manifest (`PrivacyInfo.xcprivacy`) | present for the app (3 required-reason APIs) and
  for the watch (UserDefaults only). The widget needs none: it touches no required-reason API. |
| App icon, 1024pt, light + dark + tinted | present for the phone app, regenerable via
  `Tools/GenerateAppIcon.swift`. Present for the watch app too, via
  `BronzlaWatch/Assets.xcassets` plus the `CFBundleIconName` partial plist. |
| Localisation | **English is the source language**, Turkish a full translation. Three catalogues, one per bundle that displays text: `Bronzla/Resources` (359), `BronzlaWidgets` (19), `BronzlaWatch` (16). Verified by rendering each locale and reading the screen, not by counting entries: every prior count has been wrong in a different way. |
| Export compliance (`ITSAppUsesNonExemptEncryption`) | declared `NO`, so uploads will not prompt |
| Live Activities (`NSSupportsLiveActivities`) | declared |
| Usage descriptions (location, photos, Health) | English in `INFOPLIST_KEY_*`, Turkish via `Bronzla/Resources/InfoPlist.xcstrings`. A catalogue with only `tr` makes English fall back to the raw key name in the system prompt. |
| Instagram Stories sharing (`LSApplicationQueriesSchemes`) | declared via a partial Info.plist
  (`Config/Bronzla-Info.plist`); array keys do not survive `INFOPLIST_KEY_` on this project |
| Launch screen | declared as an empty `UILaunchScreen` dict in `Config/Bronzla-Info.plist`. `INFOPLIST_KEY_UILaunchScreen_Generation` emitted it nested inside itself, which iOS ignores, letterboxing the app into 320pt compatibility mode. |
| Deployment target | iOS 18.0, watchOS 11.0 |
| Version / build | 1.0 (7), consistent across all five targets |

---

## Privacy nutrition label answers

App Store Connect asks these as a questionnaire. The answers must match `PrivacyInfo.xcprivacy`.

- **Do you collect data from this app?** Yes (it stays on device, but location is sent to
  Apple Weather, so the honest answer is yes).
- **Location → Precise Location**: collected, **not** linked to identity, **not** used for
  tracking. Purpose: App Functionality.
- **Health & Fitness**: collected, not linked, not tracking. Purpose: App Functionality.
  (Sun exposure sessions.)
- **Photos**: collected, not linked, not tracking. Purpose: App Functionality.
- **User Content → Other User Content**: conservative add-on for session notes and profile
  names stored on device. If you want the strictest match to the current build, include this.
- **Contact Info, Identifiers, Usage Data, Diagnostics**: not collected.
- **Third-party advertising / analytics**: none.
- **Instagram Stories sharing**: the app checks whether Instagram is installed
  (`LSApplicationQueriesSchemes`) and, only on explicit user tap, writes a rendered share-card
  image to the pasteboard for Instagram to read. No data is sent over the network and no data
  leaves the device unless the user completes the share themselves.
- **Family leaderboard**: ranks profiles already stored on the same device. No new data is
  collected and nothing leaves the device; there is no backend.

---

## Age rating

- Unrestricted web access: **No**
- Medical/treatment information: **Yes, infrequent/mild.** The app gives sun exposure guidance.
  Declaring this is the safe answer and matches the disclaimers in the app.
- Everything else: **None**.

Expected rating: 12+.

---

## Category

- Primary: **Health & Fitness**
- Secondary: **Weather**

---

## URLs

App Store Connect makes the first two mandatory and will not let the version be submitted
without them. All are live on Cloudflare.

| Field | Value |
|---|---|
| Privacy Policy URL | `https://bronzla.app/privacy` (Turkish: `https://bronzla.app/tr/gizlilik`) |
| Support URL | `https://bronzla.app/support` (Turkish: `https://bronzla.app/tr/destek`) |
| Marketing URL (optional) | `https://bronzla.app` |

---

## App name and subtitle

**Turkish**
- Name: `Bronzla`
- Subtitle: `Güvenli güneşlenme ve UV takibi`

**English**
- Name: `Bronzla`
- Subtitle: `Safe sun and UV tracking`

---

## Keywords

**Turkish** (100 characters max, comma separated, no spaces after commas)

```
uv,güneş,bronzlaşma,cilt,spf,güneş kremi,plaj,tatil,zamanlayıcı,d vitamini,dermatoloji,yaz
```

**English**

```
uv index,sun,tanning,skin,spf,sunscreen,beach,timer,vitamin d,sunburn,summer,uv forecast
```

---

## Description

**Turkish**

```
Bronzla, güneşte ne kadar kalabileceğinizi cilt tipinize ve o anki UV indeksine göre söyler.

Reklam yok, abonelik yok, uygulama içi satın alma yok. Bir kez alırsınız, hepsi bu.

CİLT TİPİNİZE ÖZEL
Yedi soruluk Fitzpatrick testi cilt tipinizi belirler. Sorular Türkiye'ye göre hazırlandı:
Akdeniz ve Ege'de en sık görülen buğday ve zeytin tonları, kuzey Avrupa kalıplarına göre değil,
kendi referanslarıyla anlatılıyor.

GÜVENLİ SÜRE
Güncel UV indeksi, cilt tipiniz ve SPF değerinizle güvenli güneşlenme süreniz hesaplanır.
Süreler Dünya Sağlık Örgütü'nün UV indeksi tanımına ve klinik literatürdeki minimum eritem dozu
değerlerine dayanır. Güneş kreminin gerçek hayatta etiketteki kadar korumadığı da hesaba katılır.

ZAMANLAYICI
Dönme zamanı ve krem yenileme hatırlatmaları. Telefonunuz çantada, ekran kapalıyken de çalışır.
Kilit ekranında canlı olarak kalan süreyi görürsünüz.

UV TAHMİNİ
Saatlik ve 10 günlük UV tahmini. Günün en riskli saatleri açıkça belirtilir.

BRONZ TAKİPÇİ
Seanslarınızı kaydedin, fotoğraf ekleyin, seri takibi yapın. Toplam güneş süreniz ve tahmini
D vitamini üretiminiz özetlenir.

BRONZ PUANI
Puanınız güneşte geçirdiğiniz süreyi değil, disiplininizi ölçer. Yanmadan tamamladığınız
seanslar, kullandığınız koruma ve düzenliliğiniz puan kazandırır. Tek bir yanık, en iyi seansın
kazandırdığından fazlasını götürür. Rozetler de aynı mantıkla verilir: hiçbiri güneşte daha uzun
kalmayı ödüllendirmez.

PAYLAŞ
Sezon özetinizi veya tek bir seansı hazır bir kartla paylaşın. Kartta yazan şey güneşte geçen
saatler değil, sıfır yanıktır.

AİLE SIRALAMASI
Aynı cihazdaki profilleri disipline göre sıralayın. Sunucu yok, hesap yok, veriler cihazdan
çıkmaz.

APPLE WATCH
Güncel UV indeksi ve güvenli süreniz bileğinizde. Saat veriyi kendisi çeker; telefonunuz
yanınızda olmasa da çalışır.

TÜRKİYE'YE GÖRE
Antalya, Bodrum, Çeşme, Fethiye, Kaş, Alanya ve daha fazlası hazır konum olarak eklendi.
İstanbul'dayken gelecek haftanın Bodrum tahminine bakabilirsiniz.

GİZLİLİK
Hesap açmanız istenmez. Veriler cihazınızda kalır. Üçüncü taraf analiz aracı kullanılmaz.
Tüm verilerinizi tek dokunuşla silebilirsiniz.

ÖNEMLİ
Bronzla tıbbi tavsiye vermez. Süreler ortalama değerlere dayanır ve kişiden kişiye değişir.
Cildinizle ilgili endişeleriniz için dermatoloğa başvurun.
```

**English**

```
Bronzla tells you how long you can stay in the sun, based on your skin type and the UV index
right now.

Free. No ads, no subscription, no in-app purchases.

BUILT AROUND YOUR SKIN
A seven question Fitzpatrick assessment works out your skin type. The questions are written for
this market: the olive and wheat tones common along the Mediterranean and Aegean are described
on their own terms rather than against northern European reference points.

SAFE TIME
Your safe time is calculated from the current UV index, your skin type and your SPF. The figures
follow the World Health Organization's definition of the UV index and minimal erythemal dose
values from the clinical literature, and account for sunscreen performing well below its label
value in real use.

TIMER
Flip and sunscreen reminders that work with the phone in your bag and the screen off. The
remaining time stays live on your lock screen.

UV FORECAST
Hourly and 10 day UV forecasts, with the riskiest hours of the day called out plainly.

TAN TRACKER
Log sessions, add photos, track streaks. See your total time in the sun and an estimate of the
vitamin D produced.

TAN SCORE
Your score measures discipline, not hours. Sessions you finish without burning, the protection
you used and your consistency all earn points. A single burn costs more than your best session
earns. The badges work the same way: none of them rewards staying out longer.

SHARING
Share a season summary or a single session as a ready made card. What it shows is zero burns,
not hours in the sun.

FAMILY RANKING
Rank the profiles on your device by discipline. No server, no account, and nothing leaves your
device.

APPLE WATCH
The current UV index and your safe time, on your wrist. The watch fetches its own data, so it
works when your phone is not with you.

PRIVACY
No account. Your data stays on your device. No third party analytics. Delete everything with a
single tap.

IMPORTANT
Bronzla does not give medical advice. Times are based on average values and vary from person to
person. See a dermatologist about any concerns with your skin.
```

---

## Promotional text (170 characters)

**Turkish**: `Cilt tipinize ve anlık UV indeksine göre güvenli güneşlenme süreniz. Dönme ve krem hatırlatmalı zamanlayıcı, 10 günlük UV tahmini. Reklamsız, aboneliksiz.`

**English**: `Your safe sun time, based on your skin type and the UV index right now. Timer with flip and sunscreen reminders, 10 day UV forecast. No ads, no subscription.`

---

## App Review notes

Paste into the Review Notes field. This pre-empts the two most likely rejection reasons.

```
Bronzla is free, with no in-app purchases, no subscriptions and no ads. No demo account is
needed; there is no sign-in.

MEDICAL DISCLAIMER
The app provides general sun-safety guidance, not medical advice. A disclaimer appears on every
screen that shows an exposure time, and the full text is in Settings > Medical disclaimer. The app
does not diagnose, treat or claim any medical outcome.

CALCULATION BASIS
Exposure times derive from the WHO/WMO definition of the UV index (1 unit = 25 mW/m² erythemally
weighted irradiance) and published minimal erythemal dose values for Fitzpatrick phototypes I-VI.
Sunscreen protection is deliberately discounted by 50% to reflect real-world application rates.

WEATHERKIT
UV and weather data come from Apple WeatherKit. Apple Weather attribution and a link to the data
sources appear on every screen that displays this data.

LOCATION
Location is used only to fetch weather for the user's position and is never linked to an identity.
The app also works without location: users can pick a city manually.
```

---

## Screenshots

Required: 6.9" (1320 x 2868). iPad is not required; the app is iPhone-only
(`TARGETED_DEVICE_FAMILY = 1`). Because the bundle ships a watchOS app, App Store Connect also
requires a separate Apple Watch set, and a set is needed per listing locale, so both `en-US`
and `tr` once the Turkish localisation is added.

Captured from the simulator with the DEBUG-only `-screenshotMode` launch argument, which seeds
deterministic sessions and a fixed UV 8 reading in Bodrum. It deliberately does not report the
reading as `.sample`, because that would render the "showing sample data" banner into the shot.

Captured 2026-07-23 after the localisation fixes, twelve PNGs at 1320 x 2868:

| Path | Shot |
|---|---|
| `build/screenshots/{en,tr}/01-dashboard.png` | Dashboard at the pinned UV 8 reading |
| `build/screenshots/{en,tr}/02-exposure.png` | Safe-time card and advice |
| `build/screenshots/{en,tr}/03-timer.png` | Timer setup |
| `build/screenshots/{en,tr}/04-forecast.png` | UV forecast chart and 10 day outlook |
| `build/screenshots/{en,tr}/05-tracker.png` | Tan tracker calendar and streak |
| `build/screenshots/{en,tr}/06-score.png` | Family ranking |

Run with:

```
xcodebuild test -project Bronzla.xcodeproj -scheme Bronzla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:BronzlaUITests/ScreenshotTests
```

**Apple Watch**, captured for the first time on 2026-07-23, at 416 x 496 (Series 11 46mm), in
`build/screenshots/watch-{en,tr}/01-dashboard.png`. The watch had never been captured because
`WatchUVModel.refresh()` reaches WeatherKit directly with no cache or sample provider behind
it, so on a simulator it can only render `.denied` or `.failed`. `WatchScreenshotSeed` (DEBUG
only, same shape as the phone's `ScreenshotSeed`) pins the same Bodrum UV 8 reading. There is
no watch UI test; the capture is manual:

```
xcodebuild build -project Bronzla.xcodeproj -scheme BronzlaWatch -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -derivedDataPath build/dd-watch CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" PROVISIONING_PROFILE_SPECIFIER=""
xcrun simctl install <watch-udid> build/dd-watch/Build/Products/Debug-watchsimulator/BronzlaWatch.app
xcrun simctl launch <watch-udid> com.hmdcorp.bronzla.watch -screenshotMode -AppleLanguages "(tr)" -AppleLocale tr_TR
xcrun simctl io <watch-udid> screenshot shot.png
```

Signing must be disabled for the simulator build: the target carries a manual App Store
provisioning profile, and `CodeSign` fails against a simulator destination without it.

Capture with the simulator once WeatherKit signing is in place, so the readings are real:

```
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl launch booted com.hmdcorp.bronzla -AppleLanguages "(tr)" -AppleLocale tr_TR
xcrun simctl io booted screenshot shot.png
```

---

## Known limitations, stated plainly

- **Live WeatherKit data is unverified end to end**, on phone or watch. It cannot be tested
  without a signed build, which needs your Team ID. The mapping code is written and compiles,
  but no real WeatherKit response has ever been parsed by either app.
- **The Live Activity has not been observed running.** It requires a signed build on a physical
  device. The code compiles and is wired into every timer transition.
- **Photo picking and notification permission flows have no automated coverage.** XCTest cannot
  drive the system permission alerts or the PhotosUI picker.
- **The Apple Watch app has been launched and observed on a simulator only.** It installs, boots
  and renders without crashing, but has never run on a physical Watch, and has no app icon yet.
- **The Turkish App Store listing localisation has not been added to App Store Connect yet.**
  The copy below is written and ready; only `en-US` exists on the record so far.
