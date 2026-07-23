# Bronzla marketing site — brain

Scope: `web/` only, the Astro static site at bronzla.app. Separate from the root
`MEMORY.md`, which tracks the iOS app.

## Current state

Built and verified 2026-07-23: landing, features, privacy and terms pages, English and
Turkish, `pnpm build` clean with zero warnings. Not deployed; deploy is a separate task
(see `tasks/todo-web.md`, "Deploy" section, still open).

## Decisions and gotchas worth keeping

- **Locale routing uses mismatched slugs** (`/features` vs `/tr/ozellikler`, `/privacy` vs
  `/tr/gizlilik`, `/terms` vs `/tr/kosullar`). Astro's `getRelativeLocaleUrl` and friends
  assume identical path segments across locales and cannot express this pairing. Route
  pairs are hardcoded in `src/config.ts` (`ROUTE_PAIRS`, `localeCounterpart`) and drive
  both the nav locale switcher and the hreflang tags in `BaseLayout`. Any new page pair
  must be added there or the switcher silently falls back to the locale root.
- **Astro frontmatter fence must be the literal first bytes of the file.** An HTML
  comment placed before the opening `---` breaks frontmatter parsing entirely: Astro
  treats the whole file as a plain template with no imports, so `BaseLayout` etc. become
  `ReferenceError`s at build time. The "drafted, pending legal review" marker required on
  `terms.astro`/`kosullar.astro` therefore lives as a `//` comment inside the frontmatter
  block, duplicated as an HTML comment in the template body directly after it, so it is
  still visible in view-source.
- **`impeccable detect`'s static HTML/CSS mode cannot resolve `clamp()`.** Every section
  on this site pairs `border-top: 1px solid var(--hairline)` with `padding-block:
  clamp(...)`, which reads as zero padding to the static parser and fires a
  `cramped-padding` false positive on every bordered section. Verified against real
  computed styles (Playwright/WebKit `getComputedStyle`): actual padding is 24-102px.
  Suppressed via `.impeccable/config.json` (`detector.ignoreRules`) with the reasoning
  recorded in that file's `_notes` key. The Puppeteer URL-scan mode, which renders for
  real and would not need this workaround, could not be tested: the Chrome-for-Testing
  download fails silently in this sandbox and no system Chrome is installed. Worth
  retrying that mode on a machine with Chrome before trusting the suppression blindly on
  a redesign.
- **UV band strip text must be bold and >= 19.2px, not the small-text default.** Dark
  (`--surface`) text on the "extreme" band (violet) measures 3.60:1, which fails the
  4.5:1 body-text floor but clears the 3:1 large-text floor. Every other band clears 4.5:1
  even at small sizes, so the strip's numeral and name lines are set uniformly large to
  keep one consistent treatment across all five bands rather than special-casing one.
- **`--ink-faint` is only legal against plain `--surface`.** It is 5.52:1 there but drops
  to 4.90:1 on `--surface-raised` and 4.21:1 on `--surface-high`, below the 4.5:1 floor.
  `MedicalDisclaimer` and `WeatherKitAttribution` are only ever placed on the page
  background (the footer), never inside a raised panel.
- **Bricolage Grotesque woff2 subsetting splits ASCII from Turkish extras.** Google's
  `latin` file does not contain `ı İ ğ Ğ ş Ş`; `latin-ext` does but lacks plain ASCII.
  Both `@font-face` declarations are required with their original `unicode-range` values
  intact, or Turkish characters silently fall back to a system font mid-word.
- **No system Puppeteer/Lighthouse Chrome in this sandbox.** Both `npx impeccable detect
  <url>` (full-render mode) and `npx lighthouse` need a real Chromium; `puppeteer browsers
  install` fails silently here and there is no `/Applications/Google Chrome.app`. WebKit
  via Playwright works fine and was used for all rendering verification instead
  (screenshots, computed-style checks, overflow checks). Lighthouse itself has no WebKit
  equivalent, so the "performance and accessibility >= 95" gate in `tasks/todo-web.md` is
  still unverified pending a machine with Chrome.
- **`astro dev`/`astro preview` silently pick a different port if the requested one is
  taken.** A stray unrelated process was already listening on 4321 in this environment;
  `astro preview --port 4321` logged "Port 4321 is in use, trying another one" and served
  on 4322 instead. Always read the CLI's own startup log for the actual bound port before
  pointing a browser-automation script at it, rather than assuming the requested port.

## Marketing site (web/) revision pass, 2026-07-23

**Hero dead space was `align-items: center` against a tall sibling, not just padding.**
The device frame's App Store aspect ratio (1320:2868) makes it nearly viewport-height at any
reasonable width, so `align-items: center` on the hero's flex row centred the copy column
against that height and pushed the headline figure down the page. Cutting `padding-block`
alone did not fix it; the fix was `align-items: flex-start`. Any future full-height device
frame paired with shorter copy in a flex row needs `flex-start`, not `center`, or the same
dead-space bug returns.

**`flex-wrap: wrap-reverse` silently breaks mobile source order.** `Hero.astro` had
`hero-copy` first in the DOM and `hero-frame` second, correct for both a single-row desktop
layout and a no-JS crawl. But `wrap-reverse` reverses which wrapped *line* renders first once
items drop to separate lines (narrow viewports), so the second DOM child rendered above the
first with no JavaScript involved and no visible reason in the markup. Diagnosed by checking
computed layout, not by reading the JSX order. Rule of thumb: if source order must hold at
every breakpoint, use `flex-wrap: wrap`, never `wrap-reverse`, unless the reversal is the
explicit intent.

**Astro trims pure-whitespace text nodes between an expression and an inline element.**
`{text}\n<a>...</a>` inside a `<p>` rendered as `"Weather dataApple Weather"` with no space,
even though the source had a newline between them. Astro (unlike plain HTML) does not treat
that inter-expression whitespace as significant. Fix: put a literal space character in the
static text immediately before the tag, on the same source line as the expression
(`{text} <a>...</a>`), not relying on surrounding whitespace/newlines to survive compilation.

**Contrast can only be verified via a canvas round-trip when tokens are OKLCH.**
`getComputedStyle(...).color` in WebKit returns the value in whatever colour space it was
declared in (`oklch(...)` strings pass straight through), so naive RGB-regex parsing of
computed style silently produces nonsense contrast ratios (measured ~1.0 for legible text).
Correct approach: paint the computed colour string onto a 1x1 canvas and read back the
resolved sRGB pixel, then run the WCAG relative-luminance formula on that. Reusable for any
future contrast audit on this OKLCH-token site.

**DESIGN.md's "no identical card grid" ban is about icon-topped bordered cards, not any
multi-column arrangement.** Restructured the Timer section's three sub-items (Flip reminder,
Sunscreen reminder, Live on lock screen) from a stacked single column into a three-up row
divided by 1px hairlines, no boxes, no icons. This reads as a deliberate grouping rather than
an accidental narrow list, and does not trip the anti-card-grid rule because there is no
bordered card, just hairline-divided type — confirmed clean via `impeccable detect`.
