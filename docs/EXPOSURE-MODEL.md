# The exposure model

> **This is not medical advice.**
>
> Bronzla estimates sun exposure times from population-average figures. It does not know your
> medical history, your medication, your baseline vitamin D status, or how your skin actually
> behaves. Every number the app produces is an estimate with considerable error, and no number
> here should be used to make a medical decision. Photosensitising medication, a history of
> skin cancer, and conditions such as lupus or xeroderma pigmentosum all invalidate this model
> entirely. See a dermatologist about any concern with your skin. If you are burnt, treat it as
> a burn.
>
> The app carries the same disclaimer on every screen that gives exposure guidance, via
> `MedicalDisclaimer`, which is itself the tap target for the citation list.

This document describes the maths in
`App/Bronzla/Services/Exposure/ExposureCalculator.swift`, the phototype data in
`App/Bronzla/Models/SkinType.swift`, and the sources in
`App/Bronzla/Models/MedicalSource.swift`.

`ExposureCalculator` is the trust boundary of the codebase. It is pure, synchronous and
dependency-free: it holds no state, touches no network, and reads no clock it was not handed.
That is deliberate, because it is the one part of the app that can cause physical harm if it is
wrong. Every constant traces to a published source, and every change needs a test.

## Fitzpatrick phototypes

The Fitzpatrick scale, devised in 1975 and validated in Fitzpatrick's 1988 paper, classifies
skin by how it responds to ultraviolet light. It is the scale the dermatological literature uses
when reporting minimal erythemal dose, which is precisely why the app keys off it rather than
off any richer or more modern classification.

`SkinType` is a six-case enum. The descriptions are written for a Turkish and wider
Mediterranean audience: types III and IV are by far the most common in Türkiye, so the copy uses
familiar reference points rather than northern European ones.

| Type | Label | Behaviour in the sun | Recognisable description |
| --- | --- | --- | --- |
| I | Very fair | Always burns, never tans | Red or blond hair, blue or green eyes, freckles. Uncommon in Türkiye. |
| II | Fair | Burns easily, tans with difficulty | Blond or light brown hair, light eyes. Common along the Black Sea and in Thrace. |
| III | Light olive | Sometimes burns, tans gradually | Brown hair, hazel or brown eyes. One of the two most common types in Türkiye. |
| IV | Olive | Rarely burns, tans easily | Dark brown hair and eyes. Most common on the Mediterranean and Aegean coasts. |
| V | Brown | Very rarely burns, tans very easily | Near black hair, dark eyes. Common in the southeast. |
| VI | Deep brown | Almost never burns, always darkens | Black hair and eyes. Reddening is very rare. |

The phototype is either chosen directly or derived from the in-app quiz (`SkinTypeQuiz`). It is
stored on `UserProfile` and copied onto each `TanSession` at the time the session is recorded,
so historical sessions stay correct if the profile is later edited.

## Minimal erythemal dose

The minimal erythemal dose (MED) is the erythemally weighted ultraviolet energy that produces
just-perceptible reddening, assessed 24 hours after exposure, on unadapted skin.

| Type | MED (erythemally weighted J/m²) | Equivalent in SED |
| --- | --- | --- |
| I | 200 | 2.0 |
| II | 250 | 2.5 |
| III | 300 | 3.0 |
| IV | 450 | 4.5 |
| V | 600 | 6.0 |
| VI | 1000 | 10.0 |

These are midpoints of the ranges reported in the clinical literature. They are population
averages, not personal measurements. An individual's true MED can sit well outside the value for
their phototype, which is one of the reasons the app applies a safety fraction on top (see
below) and carries a disclaimer on every screen.

### Units, and a warning that matters

The units above are **erythemally weighted joules per square metre**. The standard erythema dose
is defined as 1 SED = 100 J/m² of erythemally weighted UV, so the table spans 2 to 10 SED.

**These figures are not comparable to unweighted physical doses quoted in mJ/cm².**

This confusion has already produced one false bug report against this repository, so it is worth
spelling out. Older solar-simulator studies frequently report MED as a raw radiometric dose in
mJ/cm², measured over the lamp's whole output band with no action spectrum applied. Typical
numbers there run in the tens of mJ/cm², and a naive unit conversion (1 mJ/cm² = 10 J/m²) makes
the table above look wrong by roughly an order of magnitude.

It is not wrong. The two quantities measure different things:

| | Erythemally weighted dose | Unweighted solar-simulator dose |
| --- | --- | --- |
| Typical unit | J/m² (or SED) | mJ/cm² |
| Spectrum | CIE erythema action spectrum applied | None, raw lamp output over its band |
| Depends on the source spectrum | No, that is the point of the weighting | Yes, heavily |
| Comparable to a UV index | Yes, directly | No |

The whole model is built on the erythemally weighted convention because the UV index is defined
in the same terms. Mixing the two produces an app that tells people with fair skin they have
several hours. Before proposing that a MED constant is wrong, check which convention the source
uses.

## The core calculation

The UV index is defined, by the WHO and WMO, such that one index unit equals 25 mW/m² of
erythemally weighted irradiance. That single definition is what connects a weather forecast to a
burn time.

```
irradiance (W/m²) = uvIndex × 0.025
time to burn (s)  = MED (J/m²) / irradiance × protectionFactor
```

`irradiancePerUVIndexUnit = 0.025` is not a tunable. It is the definition of the scale.

Worked example, phototype III under UV 8, bare skin:

```
irradiance = 8 × 0.025      = 0.2 W/m²
burn time  = 300 / 0.2      = 1500 s = 25 minutes
```

which agrees with published erythema tables. `timeToBurn` returns `nil` when the UV index is
zero or below, because there is no erythemal risk to report rather than an infinite time.

Burn times at UV 8 on bare skin, for reference:

| Type | Time to one MED | Recommended session |
| --- | --- | --- |
| I | 17 min | 10 min |
| II | 21 min | 13 min |
| III | 25 min | 15 min |
| IV | 38 min | 23 min |
| V | 50 min | 30 min |
| VI | 83 min | 50 min |

### The safety fraction

`recommendedSession` returns 60 per cent of the burn time, not the burn time itself:

```swift
static let safeSessionFraction: Double = 0.6
```

Staying below one MED is what separates tanning from burning. Melanogenesis is stimulated well
before reddening appears, so a sub-erythemal session still produces a tan. The remaining 40 per
cent is headroom for the model's own error, which is considerable: population-average MED,
forecast UV rather than measured UV, no account of albedo from sand or water, no account of
altitude, and no account of how much of the body is actually in the sun.

### Accumulated dose

For a session at a constant UV index:

```
dose (J/m²) = irradiance × seconds / protectionFactor
```

For a session that straddles the afternoon peak, `dose(across:from:to:spf:)` integrates over the
hourly forecast samples, clipping each hour to the overlap with the session window. This matters
in practice: an hour either side of solar noon can carry twice the irradiance of an hour at
16:00, and treating the session as flat would understate the dose.

`burnRisk` expresses accumulated dose as a fraction of the phototype's MED. A value of 1.0 means
reddening is expected. This is the figure stored on each `TanSession` and the figure `BronzScore`
uses to decide whether a session was clean.

## Sunscreen

SPF is measured under ISO 24444 at an application rate of 2 mg per square centimetre of skin.
Nobody applies that much. Petersen and Wulf (2014) found real-world application is roughly a
third of the test dose, and protection falls off faster than linearly with thickness, so
effective protection sits well below the label figure.

The app applies a flat efficiency haircut rather than pretending the label:

```swift
static let realWorldSunscreenEfficiency: Double = 0.5

static func protectionFactor(spf: Int) -> Double {
    let nominal = Double(max(spf, 1))
    guard nominal > 1 else { return 1 }
    return 1 + (nominal - 1) * realWorldSunscreenEfficiency
}
```

SPF 1, meaning bare skin, returns exactly 1: there is nothing to degrade, so no haircut applies.

| Nominal SPF | Protection factor used |
| --- | --- |
| 1 | 1.0 |
| 15 | 8.0 |
| 30 | 15.5 |
| 50 | 25.5 |

This is a modelling choice rather than a measurement, and it is a conservative one. The
alternative is telling someone wearing SPF 50 that they have twenty hours, which is both false
and dangerous.

Two related figures:

- `reapplyInterval` is fixed at two hours, sooner after swimming or towelling. Every product
  label and every dermatology body agrees on this, so it is a constant and is never derived from
  the model.
- `SkinType.recommendedSPF` is 50 for types I and II and 30 for the rest. No tier goes below 30,
  because the AAD recommends broad spectrum SPF 30 or higher for everyone regardless of
  phototype, including skin that rarely burns.

## The three-hour cap

```swift
static let maximumRecommendedSession: Duration = .seconds(3 * 60 * 60)
```

`recommendedSession` never returns more than three hours, whatever the arithmetic says.

**This is a safety policy, not a clinical figure.** There is no paper behind three hours. Two
things motivate it. First, the linear-dose assumption underlying the whole model degrades over
long sessions: forecast UV drifts from actual UV, sunscreen wears off, people move in and out of
shade, and cumulative photodamage is not usefully modelled as a single dose integral. Second, no
responsible app should print "six hours in the sun" as a recommendation, regardless of
phototype.

The cap binds most often for phototypes V and VI in moderate UV, and for anyone wearing high SPF.
Under those conditions the app is deliberately more conservative than its own maths.

## Vitamin D

`estimatedVitaminD` returns an estimate in international units:

```
IU = min(dose / MED, 1.0) × 15,000 × exposedBodyFraction × melaninEfficiency
```

Three parts, with very different levels of support.

**The plateau is real.** Synthesis self-limits at approximately one MED as previtamin D
photoisomerises to inert products, so further exposure yields no more vitamin D while continuing
to accumulate erythemal dose. This is why the fraction is clamped at 1.0, and it is the single
most useful thing the feature communicates: more sun does not mean more vitamin D.

**The whole-body yield is drawn from the literature.** Holick (2011) reports that whole-body
exposure to one MED is comparable to an oral intake of roughly 10,000 to 25,000 IU. The app uses
15,000 IU, near the lower middle of that range.

**The melanin multipliers have no published basis.** They are the app's own model estimates:

| Phototype | Multiplier |
| --- | --- |
| I, II | 1.0 |
| III, IV | 0.8 |
| V | 0.55 |
| VI | 0.4 |

Melanin competes with 7-dehydrocholesterol for the same photons, so darker phototypes do need
materially longer exposure for the same yield. That direction is well described in the
literature. The specific magnitudes above are not: they have not been validated against any
trial, and no source is cited for them because there is none. They encode a plausible shape, no
more.

`exposedBodyFraction` defaults to 0.6, roughly swimwear. Shorts and a t-shirt are around 0.25.

The estimate is deliberately crude and is labelled as such wherever it appears in the app. Real
synthesis depends on age, body composition, baseline serum 25(OH)D and prior exposure, none of
which the app knows. Do not use it to decide on supplementation.

## Session structure

`flipInterval` is simply half the session. An even split gives both sides an equal dose, and
people remember "halfway" in a way they do not remember a cleverer schedule.

## Sources

The list below is `MedicalSource.all` in `App/Bronzla/Models/MedicalSource.swift`, which is the
single canonical catalogue in the codebase. `MedicalSourcesView` renders it, and it is reachable
in one tap from every screen that gives exposure guidance. Apple's review guideline 1.4.1
requires medical citations to be easy for the user to find, not merely present somewhere.

### UV index

**World Health Organization.** *Radiation: The Ultraviolet (UV) Index.* WHO Questions and
Answers.
<https://www.who.int/news-room/questions-and-answers/item/radiation-the-ultraviolet-(uv)-index>
Backs: one UV index unit equals 25 mW/m² of erythemally weighted irradiance, and the protection
advice for each band.

**International Commission on Non-Ionizing Radiation Protection.** *UV Index.* ICNIRP.
<https://www.icnirp.org/en/applications/uv-index/index.html>
Backs: the Low, Moderate, High, Very High and Extreme band thresholds.

### Skin type

**Fitzpatrick TB (1988).** *The validity and practicality of sun-reactive skin types I through
VI.* Archives of Dermatology, 124(6), 869-871.
<https://pubmed.ncbi.nlm.nih.gov/3377516/>
Backs: the six phototypes and the burning and tanning behaviour described for each.

### Sunscreen

**International Organization for Standardization (2019).** *ISO 24444:2019 Cosmetics. Sun
protection test methods. In vivo determination of the sun protection factor (SPF).*
<https://www.iso.org/standard/72250.html>
Backs: SPF is measured at an application rate of 2 mg per square centimetre of skin.

**Petersen B, Wulf HC (2014).** *Application of sunscreen: theory and reality.*
Photodermatology, Photoimmunology and Photomedicine.
<https://onlinelibrary.wiley.com/doi/10.1111/phpp.12099>
Backs: people apply far less than the test dose in practice, so real-world protection sits well
below the label figure.

**American Academy of Dermatology.** *How to apply sunscreen.*
<https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/how-to-apply-sunscreen>
Backs: reapply every two hours, and immediately after swimming or sweating.

**American Academy of Dermatology.** *Practice Safe Sun.*
<https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/practice-safe-sun>
Backs: broad spectrum SPF 30 or higher is recommended for everyone.

### Vitamin D

**Holick MF (2011).** *Vitamin D: a D-lightful solution for health.* Journal of Internal
Medicine.
<https://pubmed.ncbi.nlm.nih.gov/21415774/>
Backs: whole-body exposure to one minimal erythemal dose is comparable to an oral intake of
roughly 10,000 to 25,000 IU.

### Aftercare

**American Academy of Dermatology.** *How to treat a sunburn.*
<https://www.aad.org/public/everyday-care/injured-skin/burns/treat-sunburn>
Backs: cool baths, aloe vera or soy products, and never popping blisters.

**Mayo Clinic.** *Sunburn: First aid.*
<https://www.mayoclinic.org/first-aid/first-aid-sunburn/basics/art-20056643>
Backs: cool compresses, and that applying ice directly damages sunburnt skin.

**Cleveland Clinic.** *When to get care for a sunburn.*
<https://health.clevelandclinic.org/when-to-get-care-for-a-sunburn>
Backs: when to seek medical care, namely dehydration, chills, nausea or extensive blistering.

## Changing this model

If you are proposing a change to any constant in `ExposureCalculator` or `SkinType`:

1. Cite the source, and check which dose convention it uses before comparing numbers.
2. Add the source to `MedicalSource.all` if it is not already there.
3. Add or update a test in `App/BronzlaTests/ExposureCalculatorTests.swift`.
4. If the change makes the app less conservative, say so explicitly in the pull request and
   justify it. Changes in that direction get more scrutiny, not less.
