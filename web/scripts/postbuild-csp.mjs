/**
 * Generates the production Content-Security-Policy after `astro build`.
 *
 * Astro inlines small hoisted scripts into the HTML rather than emitting a file, and it does
 * so whether or not the script has imports. That is good for performance and awkward for a
 * strict policy: `script-src 'self'` would block them silently, disabling the hero entrance
 * in production while everything still looked fine locally.
 *
 * Rather than relaxing the policy to `'unsafe-inline'`, this script hashes whatever inline
 * scripts the build actually produced and writes them into the policy. The result is a strict
 * CSP with no hash to maintain by hand: change the script, rebuild, and the header follows.
 */
import { createHash } from 'node:crypto';
import { readFile, writeFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';

const DIST = new URL('../dist/', import.meta.url).pathname;
const PLACEHOLDER = '__SCRIPT_HASHES__';

/** Every inline <script> body in the built output, ignoring those with a src attribute. */
const INLINE_SCRIPT = /<script(?![^>]*\ssrc=)[^>]*>([\s\S]*?)<\/script>/gi;

async function htmlFiles(dir) {
  const found = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) found.push(...(await htmlFiles(full)));
    else if (entry.name.endsWith('.html')) found.push(full);
  }
  return found;
}

const files = await htmlFiles(DIST);
const hashes = new Set();

for (const file of files) {
  const html = await readFile(file, 'utf8');
  for (const [, body] of html.matchAll(INLINE_SCRIPT)) {
    if (!body.trim()) continue;
    // The hash covers the script body byte for byte, exactly as the browser sees it.
    hashes.add(`'sha256-${createHash('sha256').update(body, 'utf8').digest('base64')}'`);
  }
}

const headersPath = join(DIST, '_headers');
const template = await readFile(headersPath, 'utf8');

if (!template.includes(PLACEHOLDER)) {
  throw new Error(`${relative(process.cwd(), headersPath)} has no ${PLACEHOLDER} placeholder.`);
}

const scriptSrc = ["'self'", ...hashes].join(' ');
await writeFile(headersPath, template.replace(PLACEHOLDER, scriptSrc), 'utf8');

console.log(
  `[csp] script-src pinned to 'self' plus ${hashes.size} inline hash${hashes.size === 1 ? '' : 'es'} across ${files.length} pages.`
);
