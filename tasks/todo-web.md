# Bronzla marketing site — bronzla.app

Astro 7 static site, English at `/`, Turkish at `/tr`, deployed to Cloudflare.
Design context: `web/PRODUCT.md` (strategy) and `web/DESIGN.md` (visual system). Both confirmed.

Separate from `tasks/todo.md`, which tracks the iOS app.

## Decisions taken

- Surface: committed dark sea-ink, `oklch(0.19 0.030 240)`. Accent `#F58D34`, inherited from the
  app's `AccentColor`. Confirmed against the tanning-brand anti-reference.
- Type: Bricolage Grotesque variable, self-hosted, subset `latin` + `latin-ext` for Turkish.
- Legal copy drafted from `APPSTORE.md`, flagged for Umut's review before launch.
- Lives at `web/` inside the TanApp repo. Xcode synchronised folder groups only watch `Bronzla/`
  and `BronzlaTests/`, so `web/` cannot reach the app target.
- No React, no Tailwind. Plain CSS with tokens, zero client JS beyond a small hero entrance.

## Build

- [x] `astro.config.mjs`: `site: 'https://bronzla.app'`, i18n (`defaultLocale: 'en'`,
      `prefixDefaultLocale: false`), `@astrojs/sitemap` with locale map.
- [x] Self-host Bricolage Grotesque woff2, `latin` + `latin-ext`, `font-display: swap`, preloaded.
- [x] `src/styles/tokens.css`: surfaces, ink, accent, UV bands, spacing, radii, z-scale, easing.
- [x] `src/config.ts`: single `SITE.appStoreUrl` constant. **Awaiting the real App Store ID.**
- [x] Shared: `BaseLayout`, nav, footer, `StoreButton`, `DeviceFrame`, `UVScale`,
      `MedicalDisclaimer`, `WeatherKitAttribution`, locale switcher.
- [x] Landing page, EN and TR.
- [x] Features page, EN and TR.
- [x] Privacy page, EN and TR, from the privacy manifest in `APPSTORE.md`.
- [x] Terms page, EN and TR, including the full medical disclaimer. Flagged pending legal review.
- [x] SEO: per-page title and description, OG and Twitter cards, hreflang pairs, `robots.txt`,
      favicon and touch icon generated from the app icon.
- [x] Screenshot slots at 1320x2868 with a documented swap path. **Awaiting Umut's screenshots.**

## Verify

- [x] `pnpm build` clean, zero warnings.
- [x] Contrast audit: every text token at or above 4.5:1, large text at or above 3:1 (see report
      in the session's final handback; `--ink-faint` restricted to plain `--surface` backgrounds,
      UV band strip text set bold and >= 19.2px so the "extreme" band's 3.60:1 clears the
      large-text floor).
- [x] Turkish render test: `İstanbul`, `Çeşme`, `güneş` at weights 200, 400, 800. Dotted/dotless
      i and cedillas confirmed correct.
- [x] Headings do not overflow at 320px, 768px and 1440px, in both languages (Playwright/WebKit
      check, zero hits). Fixed one real bug found this way: the nav overflowed horizontally on
      mobile before the locale switcher was given its own row under 480px.
- [x] `prefers-reduced-motion` honoured; content visible with JS disabled (hero entrance is
      progressive-enhancement only, gated behind a runtime `hero-animate` class the no-JS/
      reduced-motion path never adds).
- [x] Medical disclaimer on every page; WeatherKit attribution on landing and features (the pages
      that show or describe forecast data).
- [x] `npx impeccable detect` on changed files: one systemic false positive (`cramped-padding`,
      the static analyser can't resolve `clamp()` padding) verified against real computed styles
      and suppressed with a documented reason in `.impeccable/config.json`. Zero real findings.
- [ ] Lighthouse: could not run in this sandbox. No system Chrome is installed and the Puppeteer
      Chrome-for-Testing download fails silently on every retry (same root cause blocked the
      impeccable Puppeteer URL-scan mode too). Needs a machine with Chrome, or `PUPPETEER_
      EXECUTABLE_PATH` pointed at one.

## Deploy

- [x] Cloudflare Worker with static assets (`wrangler.jsonc`), chosen over Pages: Cloudflare
      recommends Workers for new projects and the site is asset-only, so no Worker runs per
      request. Zone was already on Cloudflare nameservers.
- [x] Custom domains attached: `bronzla.app` and `www.bronzla.app`, both serving 200 over HTTPS.
- [x] Cache headers via `public/_headers`: immutable for `/_astro/*` and `/fonts/*`,
      `max-age=0, must-revalidate` for HTML. Verified live.
- [x] Security headers: HSTS preload, nosniff, DENY framing, strict referrer, locked-down
      Permissions-Policy, and a strict CSP whose `script-src` hash is generated at build time by
      `scripts/postbuild-csp.mjs` (Astro inlines small scripts regardless of imports, so a static
      `'self'` policy would have silently disabled the hero entrance).
- [x] URL consistency: canonical, sitemap, hreflang and every internal link now agree on the
      trailing slash, so no internal navigation costs a 307 hop.
- [x] Deploy verified green: apex, www, both locales, all four page types.

## Outstanding: Cloudflare Web Analytics beacon

Cloudflare's edge injects `static.cloudflareinsights.com/beacon.min.js` into the HTML for
browser requests. The site states "No third party analytics" and the App Store privacy answers
declare none, so this contradicts the product's own claim. The CSP currently blocks it from
executing, but the tag is still in the markup and the fix belongs at source.

Umut must disable it: Cloudflare dashboard, `bronzla.app` zone, Web Analytics, turn off
automatic setup. The deploy token only holds `zone (read)`, so this cannot be done from here.

## Blocked on Umut

1. **App Store ID** for the badge link. Wired to one constant; site ships with a placeholder until
   provided.
2. **Six App Store screenshots**, Turkish and English.
3. **Legal review** of the drafted privacy and terms copy.
