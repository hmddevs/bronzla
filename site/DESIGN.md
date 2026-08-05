# Design

## Visual Theme

**Shade, not bronze.** A single committed dark surface: deep Aegean water seen from under an
awning. The category reflex for a sun app is cream, sand and a sunset gradient, which is also
precisely the tanning-brand look this project bans. Inverting it is the point. The site is dark,
cool and calm, and the only warmth on screen is the one colour that carries meaning.

Colour strategy: **Committed**. The sea-ink surface holds roughly 80% of every viewport. The
brand orange is a signal, never a wash, and never appears as a gradient behind text.

Scene: someone at home in Istanbul on a June evening, laptop open, planning a week in Cesme.
Considered, indoors, unhurried. That is why dark reads as calm here rather than as costume.

One theme only. There is no light mode; a second theme would halve the attention paid to the
first, and the committed surface is the identity.

## Color Palette

OKLCH throughout. Neutrals are tinted 0.025 to 0.032 chroma toward the surface's own blue, never
toward warm-by-default.

### Surfaces

| Token | Value | Use |
|---|---|---|
| `--surface` | `oklch(0.19 0.030 240)` | Page background |
| `--surface-raised` | `oklch(0.24 0.032 240)` | Panels, device frames |
| `--surface-high` | `oklch(0.29 0.030 240)` | Inputs, hovered panels |
| `--hairline` | `oklch(0.38 0.025 240)` | 1px borders and rules |

### Ink

| Token | Value | Contrast on `--surface` | Use |
|---|---|---|---|
| `--ink` | `oklch(0.97 0.008 240)` | 15.8:1 | Headings, body |
| `--ink-muted` | `oklch(0.78 0.018 240)` | 8.9:1 | Secondary prose, captions |
| `--ink-faint` | `oklch(0.64 0.020 240)` | 5.2:1 | Metadata, legal fine print |

`--ink-faint` is the floor. Nothing below 4.5:1 ships, including placeholder text. There is no
"decorative grey" tier, because that is the single most common way a dark page becomes unreadable.

### Brand and signal

| Token | Value | Hex origin | Use |
|---|---|---|---|
| `--accent` | `oklch(0.74 0.146 58)` | `#F58D34`, the app's `AccentColor` | Buttons, links, the hero figure |
| `--accent-hover` | `oklch(0.80 0.140 62)` | app dark-mode accent | Hover and focus |
| `--accent-ink` | `oklch(0.19 0.030 240)` | = `--surface` | Text *on* an accent fill |

`--accent` on `--surface` is 8.1:1, so it is safe for large display type and for link text.
`--accent-ink` on `--accent` is 8.1:1 inverted, so filled buttons are legible.

### UV band scale

Lifted verbatim from `Bronzla/DesignSystem/Palette.swift`. This is an instrument, not decoration,
which is why it is the one colourful element the design permits.

| Band | Value | App source |
|---|---|---|
| Low | `oklch(0.70 0.140 155)` | `rgb(0.24, 0.72, 0.47)` |
| Moderate | `oklch(0.84 0.150 90)` | `rgb(0.96, 0.78, 0.24)` |
| High | `oklch(0.74 0.146 58)` | `rgb(0.96, 0.55, 0.20)` |
| Very high | `oklch(0.62 0.190 30)` | `rgb(0.90, 0.29, 0.26)` |
| Extreme | `oklch(0.56 0.190 310)` | `rgb(0.60, 0.33, 0.78)` |

The brand accent and the "High" band are the same colour. That is deliberate and worth keeping:
the identity is the reading the app exists to warn you about.

**Rule:** the scale never communicates by hue alone. Every band on the site carries its numeral
range and its name in text, matching the app's colour-vision-deficiency rule.

## Typography

### Family

**Bricolage Grotesque**, variable, self-hosted as woff2, axes `opsz 12..96` and `wght 200..800`.
One family for the whole site.

Chosen against the brief's three voice words: *sun-bleached, calm, exact*. The reflex picks
(Inter, DM Sans, a geometric grotesk) are training-data defaults and were rejected. Bricolage has
a slightly irregular, sign-painted quality at display sizes that reads as easygoing, and settles
into a plain workhorse at body sizes, so a single family carries both registers without the
timid display-plus-body pairing.

A second family was considered and rejected: two grotesks would have been similar-but-not-identical,
and committed weight and size contrast within one family is stronger.

**Turkish coverage is a hard gate.** Subset to `latin` + `latin-ext`; `latin-ext` is where
`ı İ ğ Ğ ş Ş` live. Verified before selection. Render-test `İstanbul`, `Çeşme`, `güneş` at 200,
400 and 800 before shipping.

### Scale

Fluid, ratio 1.25 or greater between steps.

| Step | Value | Tracking | Line height |
|---|---|---|---|
| Figure | `clamp(4.5rem, 1.5rem + 13vw, 9.5rem)` | `-0.045em` | 0.85 |
| Display | `clamp(2.75rem, 1.5rem + 5vw, 5.5rem)` | `-0.03em` | 1.02 |
| H2 | `clamp(2rem, 1.2rem + 2.6vw, 3.25rem)` | `-0.02em` | 1.1 |
| H3 | `clamp(1.35rem, 1.1rem + 0.9vw, 1.75rem)` | `-0.01em` | 1.25 |
| Lede | `clamp(1.1875rem, 1.05rem + 0.65vw, 1.5rem)` | `0` | 1.45 |
| Body | `clamp(1.0625rem, 1rem + 0.25vw, 1.1875rem)` | `0` | 1.65 |
| Small | `0.9375rem` | `0.005em` | 1.55 |
| Micro | `0.8125rem` | `0.08em to 0.11em` | 1.4 |

Display ceiling is 5.5rem, under the 6rem limit. Tracking floor is `-0.03em`, above the `-0.04em`
limit. Body line height is 1.65 rather than 1.55, because light type on a dark surface reads as
lighter weight and needs the extra room.

**Figure** is the one step above Display and exists for a single element: the hero's safe-time
numeral. It is a tabular numeral, never a heading, and never appears twice on a page. Its tighter
tracking is legitimate at that size, where the default sidebearings read as gaps. **Lede** is the
paragraph directly under a heading, one step above body so the entry to a section is not set at
the same size as the section. **Micro** is the eyebrow, table header and metadata step; it is
always uppercase with open tracking and never carries prose.

Weight is the first lever of hierarchy, ahead of scale, and colour is last: `--weight-display: 800`,
`--weight-strong: 700`, `--weight-medium: 600`, `--weight-body: 400`. A heading that needs colour
to read as a heading has failed at the two steps before it.

`text-wrap: balance` on h1 to h3. `text-wrap: pretty` on prose. Measure capped at 68ch.

Turkish runs roughly 15 to 20 per cent longer than English. Every heading is tested at both
lengths at every breakpoint; the clamp maximum comes down before the copy gets rewritten.

## Layout

- Content column 68ch for prose, 1200px maximum for full sections, 24px gutters rising to 48px.
- Fluid section rhythm via `clamp()`. Vary it: the hero and the store call to action get generous
  separation, the evidence block and its citations sit tight together. Uniform vertical padding
  is what makes a page read as generated.
- Three densities, and pages compose them rather than repeating one: `--space-tight`
  (`clamp(2rem, 3.5vw, 3rem)`), `--space-section` (`clamp(3.5rem, 6vw, 6rem)`), `--space-open`
  (`clamp(5rem, 10vw, 10rem)`). The landing page runs open, dense panel, section, tight, open,
  closing panel. Two adjacent sections at the same density need a reason.
- **Hanging headings on long-form pages.** `.prose`, the Q&A lists and the terms list put the
  heading or question in a `--margin-col` (15rem) column and the body at the 68ch measure beside
  it. A single 68ch column left-aligned inside a 1200px page leaves half the viewport empty,
  which is the shape that made these pages read as an unstyled document. Collapses to one column
  below 63rem.
- Flexbox for one dimension, Grid for two. `repeat(auto-fit, minmax(280px, 1fr))` where a genuine
  grid is needed, so there are no breakpoint jumps.
- Asymmetry is permitted and encouraged in the hero: the figure and the device frame do not need
  to be a symmetrical two-column split.
- **No identical card grid.** Feature sections differ in shape from one another. If three
  same-sized panels with an icon above a heading appear, the section is rewritten.

### Z-index scale

Semantic only, no arbitrary values: `--z-sticky: 100`, `--z-overlay: 200`, `--z-modal: 300`,
`--z-toast: 400`.

## Components

- **Store button.** Filled `--accent`, `--accent-ink` label, radius 12px. The single loudest
  element on the page. It appears in the hero and once more at the foot; nowhere else.
- **Eyebrow.** Micro type, uppercase, open tracking, `--ink-faint`, preceded by a short rule. It
  names a section before the heading makes its claim. One eyebrow per section, and at most one
  per view carries the accent (`.eyebrow-signal`), marking the UV-risk idea.
- **Data strip.** A row of labelled values divided by hairlines: label in micro type,
  value at H3 size in tabular numerals. Used where a page states the inputs behind a figure, as
  the hero does with UV index, skin type and SPF. It is the app's readout idiom, and the reason
  the site never needs a card grid to present three related facts.
- **Device frame.** A bezel on `--surface-high` holding a screen on `--surface-raised`, 1px
  `--hairline`, radius 32px, at the App Store 1320x2868 aspect. Until real screenshots arrive it
  holds a designed empty state, never a plain coloured rectangle: the screen's index and reading
  as a header row, its name in full ink, and an explicit "screenshot to follow" line at the foot.
  All text sits on the screen and never on the bezel, because `--ink-faint` measures 4.19:1
  against `--surface-high` and would fail AA there. A `compact` variant reduces the type and
  padding for narrow placements.
- **UV scale strip.** Horizontal, five bands, each with its numeral range and name. Used once on
  the landing page and once on the features page.
- **Evidence note.** Small-type block for the WHO citation, the MED reference and the fifty per
  cent sunscreen discount. Rules above and below, no side stripe, no tinted callout box.
- **Medical disclaimer.** Persistent, `--ink-faint`, in the footer of every page. Required by the
  app's own non-negotiables and by App Review.
- **WeatherKit attribution.** Apple Weather mark plus the data-sources link, on every page that
  shows or describes forecast data. Omitting it is an App Review rejection.

Radii: 12px controls, 16px panels, 32px device frames. Borders are 1px `--hairline`; there are no
thick coloured side borders anywhere.

## Motion

- Easing `cubic-bezier(0.22, 1, 0.36, 1)` (ease-out-quint). Durations 180ms for controls, 320ms
  for section reveals. No bounce, no elastic.
- One orchestrated hero entrance on first load: the figure counts up, the device frame settles.
  It runs once and is not repeated per section. Scroll-triggered fades on every section are the
  uniform reflex and are banned.
- Only `transform` and `opacity` animate. Layout properties do not.
- **Content is visible by default.** Reveals enhance an already-rendered page; visibility is
  never gated behind a class-triggered transition, or the section ships blank to crawlers and
  background tabs.
- `prefers-reduced-motion: reduce` removes the count-up and replaces every reveal with an instant
  or crossfade state. Non-negotiable.

## Imagery

Screenshots are the imagery, and they are the proof. Six screens, supplied by Umut from App Store
Connect: dashboard at a high reading, safe-time card, timer running, UV forecast, tan tracker,
skin type result.

Until they land, device frames hold correctly-proportioned labelled slots, and the swap path is a
single documented directory. Coloured blocks standing in for screenshots are a bug, not restraint.

No stock photography of beaches, skin or sunbathers. That is the tanning-brand lane, and it is
banned by the brief.
