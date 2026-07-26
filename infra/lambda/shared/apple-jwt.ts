import { importJWK, jwtVerify, type JWTPayload } from "jose";

const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";

// One hour: long enough that a warm Lambda does not hammer Apple's JWKS
// endpoint on every invocation, short enough that a genuine key rotation is
// picked up within a single warm container's realistic lifetime.
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000;

// An unknown `kid` is the signal that Apple has rotated its signing keys, so
// the cache is refetched rather than serving a stale set for up to an hour
// and rejecting every legitimate sign-in in the meantime. The `kid` comes
// from an unauthenticated request body, so an attacker could otherwise send
// a stream of random `kid` values and turn this into a refetch amplifier
// against Apple's endpoint: a floor caps forced refetches to one per minute
// per warm container.
const JWKS_MIN_REFETCH_INTERVAL_MS = 60 * 1000;

interface AppleJwk {
  kty: string;
  kid: string;
  use: string;
  alg: string;
  n: string;
  e: string;
}

interface AppleJwks {
  keys: AppleJwk[];
}

export type JwksFetcher = () => Promise<AppleJwks>;

interface JwksCacheEntry {
  jwks: AppleJwks;
  fetchedAt: number;
}

// Module-level cache, deliberately keyed by the fetcher reference so tests
// that inject their own mock fetcher never see a previous test's cached
// keys (each test constructs a fresh fetcher, so it never collides).
const cacheByFetcher = new WeakMap<JwksFetcher, JwksCacheEntry>();

// Apple's JWKS endpoint is a third party dependency invoked on every
// unauthenticated auth request; a hang there must not consume the whole
// Lambda timeout budget.
const JWKS_FETCH_TIMEOUT_MS = 5_000;

const defaultFetcher: JwksFetcher = async () => {
  const response = await fetch(APPLE_JWKS_URL, { signal: AbortSignal.timeout(JWKS_FETCH_TIMEOUT_MS) });
  if (!response.ok) {
    throw new Error(`Apple JWKS fetch failed with status ${response.status}`);
  }
  return (await response.json()) as AppleJwks;
};

async function getJwks(fetcher: JwksFetcher, forceRefresh = false): Promise<AppleJwks> {
  const cached = cacheByFetcher.get(fetcher);
  const now = Date.now();

  if (cached) {
    const age = now - cached.fetchedAt;
    const expired = age >= JWKS_CACHE_TTL_MS;
    const forcedRefreshAllowed = forceRefresh && age >= JWKS_MIN_REFETCH_INTERVAL_MS;
    if (!expired && !forcedRefreshAllowed) {
      return cached.jwks;
    }
  }

  const jwks = await fetcher();
  cacheByFetcher.set(fetcher, { jwks, fetchedAt: now });
  return jwks;
}

/** Exposed only for tests, so a mock fetcher's cache can be forced to expire. */
export function _clearJwksCacheForTests(fetcher: JwksFetcher): void {
  cacheByFetcher.delete(fetcher);
}

export interface VerifiedAppleToken {
  sub: string;
}

export class AppleTokenVerificationError extends Error {}

/**
 * Verifies an Apple identity token: RS256 signature against Apple's published
 * JWKS (matched by kid), audience equal to the configured bundle ID, issuer
 * equal to Apple's issuer, and expiry in the future. Throws
 * AppleTokenVerificationError on any failure; callers must not surface the
 * raw error message or token to clients.
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  bundleId: string,
  fetcher: JwksFetcher = defaultFetcher
): Promise<VerifiedAppleToken> {
  if (typeof identityToken !== "string" || identityToken.length === 0) {
    throw new AppleTokenVerificationError("missing identity token");
  }

  // Defence in depth: jose's jwtVerify only compares `aud` when the
  // `audience` option is truthy. An empty/missing bundleId here must fail
  // loudly rather than silently degrade into "any Apple-signed token for
  // any app is accepted" (see auth-apple.ts's own cold-start assertion,
  // which is the primary guard; this is the belt-and-braces backstop).
  if (typeof bundleId !== "string" || bundleId.length === 0) {
    throw new AppleTokenVerificationError("missing bundle id for audience check");
  }

  const parts = identityToken.split(".");
  if (parts.length !== 3) {
    throw new AppleTokenVerificationError("malformed token");
  }

  let header: { kid?: string; alg?: string };
  try {
    header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
  } catch {
    throw new AppleTokenVerificationError("malformed token header");
  }

  if (!header.kid) {
    throw new AppleTokenVerificationError("token header missing kid");
  }

  let jwks = await getJwks(fetcher);
  let matchingKey = jwks.keys.find((key) => key.kid === header.kid);
  if (!matchingKey) {
    // Treat an unknown kid as a possible key rotation and retry once against
    // freshly fetched keys before rejecting (see JWKS_MIN_REFETCH_INTERVAL_MS).
    jwks = await getJwks(fetcher, true);
    matchingKey = jwks.keys.find((key) => key.kid === header.kid);
  }
  if (!matchingKey) {
    throw new AppleTokenVerificationError("no matching JWKS key for kid");
  }

  let payload: JWTPayload;
  try {
    // Hardcode RS256 rather than trusting the remote JWKS response's `alg`
    // field: only ever verify with the algorithm this code expects, never
    // whatever the response happens to claim.
    const publicKey = await importJWK(matchingKey, "RS256");
    const result = await jwtVerify(identityToken, publicKey, {
      algorithms: ["RS256"],
      audience: bundleId,
      issuer: APPLE_ISSUER,
    });
    payload = result.payload;
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown verification error";
    throw new AppleTokenVerificationError(`signature/claims verification failed: ${reason}`);
  }

  if (typeof payload.sub !== "string" || payload.sub.length === 0) {
    throw new AppleTokenVerificationError("token missing sub claim");
  }

  return { sub: payload.sub };
}
