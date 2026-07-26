/**
 * Single source of truth for site-wide constants. Every store link and locale-aware
 * navigation link reads from here so there is one place to update when the App Store
 * listing goes live.
 */

export const SITE = {
  appStoreUrl: 'https://apps.apple.com/tr/app/bronzla/id6793729675',
  name: 'Bronzla',
  url: 'https://bronzla.app',
} as const;

export type Locale = 'en' | 'tr';

/**
 * English and Turkish routes do not share path segments (`/features` versus
 * `/tr/ozellikler`), so Astro's built-in `getRelativeLocaleUrl` helper cannot infer the
 * pairing. This map is the explicit source for the locale switcher and for hreflang tags.
 */
export const ROUTE_PAIRS: Array<{ en: string; tr: string }> = [
  { en: '/', tr: '/tr' },
  { en: '/features', tr: '/tr/ozellikler' },
  { en: '/privacy', tr: '/tr/gizlilik' },
  { en: '/terms', tr: '/tr/kosullar' },
  { en: '/support', tr: '/tr/destek' },
];

/**
 * Astro builds directory-style routes, so `/privacy` only ever resolves via a 307 to
 * `/privacy/`. Every emitted URL therefore carries the trailing slash: canonical tags, the
 * sitemap and internal links all agree, and no internal navigation costs a redirect hop.
 */
export function withSlash(path: string): string {
  if (path === '/') return path;
  return path.endsWith('/') ? path : `${path}/`;
}

/** Given the current path in one locale, find its counterpart in the other. */
export function localeCounterpart(currentPath: string, currentLocale: Locale): string {
  const pair = ROUTE_PAIRS.find((p) => p[currentLocale] === currentPath);
  if (!pair) return withSlash(currentLocale === 'en' ? '/tr' : '/');
  return withSlash(currentLocale === 'en' ? pair.tr : pair.en);
}
