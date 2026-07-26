import { describe, expect, it } from "vitest";
import { exportJWK, generateKeyPair, SignJWT } from "jose";
import {
  AppleTokenVerificationError,
  verifyAppleIdentityToken,
  type JwksFetcher,
} from "../lambda/shared/apple-jwt";

const BUNDLE_ID = "com.hmdcorp.bronzla";
const ISSUER = "https://appleid.apple.com";
const KID = "test-key-1";

async function buildTestKeyPair() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const publicJwk = await exportJWK(publicKey);
  publicJwk.kid = KID;
  publicJwk.alg = "RS256";
  publicJwk.use = "sig";
  return { privateKey, publicJwk };
}

function fetcherReturning(jwk: Awaited<ReturnType<typeof exportJWK>>): JwksFetcher {
  // A fresh function reference per test, so the module-level JWKS cache
  // (keyed by fetcher identity) never leaks state between test cases.
  return async () => ({ keys: [jwk as never] });
}

describe("verifyAppleIdentityToken", () => {
  it("accepts a validly signed token with matching audience and issuer", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "RS256", kid: KID })
      .setSubject("apple-sub-123")
      .setIssuer(ISSUER)
      .setAudience(BUNDLE_ID)
      .setIssuedAt()
      .setExpirationTime("10m")
      .sign(privateKey);

    const result = await verifyAppleIdentityToken(token, BUNDLE_ID, fetcherReturning(publicJwk));

    expect(result.sub).toBe("apple-sub-123");
  });

  it("rejects an expired token", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "RS256", kid: KID })
      .setSubject("apple-sub-123")
      .setIssuer(ISSUER)
      .setAudience(BUNDLE_ID)
      .setIssuedAt(Math.floor(Date.now() / 1000) - 3600)
      .setExpirationTime(Math.floor(Date.now() / 1000) - 60)
      .sign(privateKey);

    await expect(
      verifyAppleIdentityToken(token, BUNDLE_ID, fetcherReturning(publicJwk))
    ).rejects.toBeInstanceOf(AppleTokenVerificationError);
  });

  it("rejects a token with the wrong audience", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "RS256", kid: KID })
      .setSubject("apple-sub-123")
      .setIssuer(ISSUER)
      .setAudience("com.someoneelse.otherapp")
      .setIssuedAt()
      .setExpirationTime("10m")
      .sign(privateKey);

    await expect(
      verifyAppleIdentityToken(token, BUNDLE_ID, fetcherReturning(publicJwk))
    ).rejects.toBeInstanceOf(AppleTokenVerificationError);
  });

  it("rejects a token signed with a key not present in the JWKS", async () => {
    const { publicJwk } = await buildTestKeyPair();
    const { privateKey: otherPrivateKey } = await buildTestKeyPair();

    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "RS256", kid: KID })
      .setSubject("apple-sub-123")
      .setIssuer(ISSUER)
      .setAudience(BUNDLE_ID)
      .setIssuedAt()
      .setExpirationTime("10m")
      .sign(otherPrivateKey);

    await expect(
      verifyAppleIdentityToken(token, BUNDLE_ID, fetcherReturning(publicJwk))
    ).rejects.toBeInstanceOf(AppleTokenVerificationError);
  });

  it("rejects a malformed token", async () => {
    await expect(
      verifyAppleIdentityToken("not-a-jwt", BUNDLE_ID, async () => ({ keys: [] }))
    ).rejects.toBeInstanceOf(AppleTokenVerificationError);
  });

  it("rejects an otherwise-valid token when bundleId is empty, rather than silently skipping the audience check", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "RS256", kid: KID })
      .setSubject("apple-sub-123")
      .setIssuer(ISSUER)
      .setAudience(BUNDLE_ID)
      .setIssuedAt()
      .setExpirationTime("10m")
      .sign(privateKey);

    await expect(
      verifyAppleIdentityToken(token, "", fetcherReturning(publicJwk))
    ).rejects.toBeInstanceOf(AppleTokenVerificationError);
  });
});
