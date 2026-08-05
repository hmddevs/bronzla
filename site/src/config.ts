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
  { en: '/science', tr: '/tr/bilim' },
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

/** Absolute URL for a site-relative path, with the trailing slash `withSlash` requires. */
export function absoluteUrl(path: string): string {
  return new URL(withSlash(path), SITE.url).toString();
}

/**
 * Builds a schema.org BreadcrumbList for an inner page. Home is always the first item;
 * `trail` supplies the remaining crumbs in order, ending with the current page.
 */
export function breadcrumbList(
  trail: Array<{ name: string; path: string }>,
  locale: Locale,
): Record<string, unknown> {
  const home = locale === 'tr' ? { name: 'Ana sayfa', path: '/tr' } : { name: 'Home', path: '/' };
  const items = [home, ...trail];
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: absoluteUrl(item.path),
    })),
  };
}

/** The Organization behind Bronzla, reused wherever a page cites the publisher. */
export function organizationSchema(): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'HMD Developments',
    url: 'https://guden.tr',
    email: 'umut@guden.tr',
  };
}
