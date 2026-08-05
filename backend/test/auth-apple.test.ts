import { createHmac } from "node:crypto";
import { afterEach, describe, expect, it, vi } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { exportJWK, generateKeyPair, SignJWT } from "jose";

const BUNDLE_ID = "com.hmdcorp.bronzla";
const ISSUER = "https://appleid.apple.com";
const KID = "test-key-1";
const SESSIONS_TABLE = "BronzlaSessions-test";
const USERS_TABLE = "BronzlaUsers-test";

async function buildTestKeyPair() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const publicJwk = await exportJWK(publicKey);
  publicJwk.kid = KID;
  publicJwk.alg = "RS256";
  publicJwk.use = "sig";
  return { privateKey, publicJwk };
}

function stubJwksFetch(keys: unknown[]): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({
      ok: true,
      json: async () => ({ keys }),
    }))
  );
}

function base64url(input: string | Buffer): string {
  return Buffer.from(input).toString("base64url");
}

/**
 * Forges an algorithm-confusion token: header claims HS256, signed with the
 * RSA public key's `n` component used as an HMAC secret, the classic
 * RS256-to-HS256 downgrade attack. apple-jwt.ts must reject this because it
 * hardcodes RS256 rather than trusting the token's own alg header.
 */
function forgeAlgorithmConfusionToken(kid: string, rsaModulusB64Url: string): string {
  const header = { alg: "HS256", kid };
  const payload = {
    sub: "apple-sub-confused",
    iss: ISSUER,
    aud: BUNDLE_ID,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 600,
  };
  const headerB64 = base64url(JSON.stringify(header));
  const payloadB64 = base64url(JSON.stringify(payload));
  const secret = Buffer.from(rsaModulusB64Url, "base64url");
  const signature = createHmac("sha256", secret).update(`${headerB64}.${payloadB64}`).digest("base64url");
  return `${headerB64}.${payloadB64}.${signature}`;
}

/**
 * Every test needs a module-fresh handler: the JWKS cache in apple-jwt.ts is
 * keyed by the default fetcher's function identity, and that identity only
 * changes across a module reset. Without this, a JWKS response stubbed in
 * one test would leak into the next test's cache.
 */
async function loadHandler() {
  vi.resetModules();
  const dynamo = await import("../lambda/shared/dynamo");
  const authApple = await import("../lambda/auth-apple");
  return { handler: authApple.handler, docClient: dynamo.docClient };
}

function buildEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "POST /auth/apple",
    rawPath: "/auth/apple",
    rawQueryString: "",
    headers: {},
    requestContext: { requestId: "test-request-id" } as APIGatewayProxyEventV2["requestContext"],
    body: JSON.stringify({ identityToken: "token" }),
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

async function signValidToken(
  privateKey: CryptoKey,
  overrides: { sub?: string; issuer?: string; audience?: string; expiresIn?: string | number } = {}
) {
  let builder = new SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: KID })
    .setSubject(overrides.sub ?? "apple-sub-123")
    .setIssuer(overrides.issuer ?? ISSUER)
    .setAudience(overrides.audience ?? BUNDLE_ID)
    .setIssuedAt();

  if (typeof overrides.expiresIn === "number") {
    builder = builder.setExpirationTime(overrides.expiresIn);
  } else {
    builder = builder.setExpirationTime(overrides.expiresIn ?? "10m");
  }

  return builder.sign(privateKey);
}

describe("auth-apple handler", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("creates a session and a new user row for a first-time Apple sign-in", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey);

    const { handler, docClient } = await loadHandler();
    const ddbMock = mockClient(docClient);
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: undefined });
    ddbMock.on(PutCommand).resolves({});

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: token, displayName: "New User" }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number; body: string };

    expect(response.statusCode).toBe(200);
    const parsed = JSON.parse(response.body) as { sessionToken: string; displayName: string };
    expect(parsed.sessionToken).toBeTypeOf("string");
    expect(parsed.sessionToken.length).toBeGreaterThan(0);
    expect(parsed.displayName).toBe("New User");

    const userPut = ddbMock
      .commandCalls(PutCommand)
      .find((call) => call.args[0].input.TableName === USERS_TABLE);
    expect(userPut?.args[0].input.Item).toMatchObject({ appleSub: "apple-sub-123", displayName: "New User" });

    const sessionPut = ddbMock
      .commandCalls(PutCommand)
      .find((call) => call.args[0].input.TableName === SESSIONS_TABLE);
    expect(sessionPut?.args[0].input.Item).toMatchObject({ appleSub: "apple-sub-123" });
  });

  it("preserves the original createdAt and existing displayName for a returning user", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey);

    const { handler, docClient } = await loadHandler();
    const ddbMock = mockClient(docClient);
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({
      Item: { appleSub: "apple-sub-123", displayName: "Old Name", createdAt: "2025-01-01T00:00:00.000Z" },
    });
    ddbMock.on(PutCommand).resolves({});

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: token }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number; body: string };

    expect(response.statusCode).toBe(200);
    const parsed = JSON.parse(response.body) as { displayName: string };
    expect(parsed.displayName).toBe("Old Name");

    const userPut = ddbMock
      .commandCalls(PutCommand)
      .find((call) => call.args[0].input.TableName === USERS_TABLE);
    expect(userPut?.args[0].input.Item).toMatchObject({
      appleSub: "apple-sub-123",
      displayName: "Old Name",
      createdAt: "2025-01-01T00:00:00.000Z",
    });
  });

  it("rejects a token with a tampered signature", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey);
    const tamperedToken = `${token.slice(0, -4)}abcd`;

    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: tamperedToken }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("rejects an expired identity token", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey, { expiresIn: Math.floor(Date.now() / 1000) - 60 });

    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: token }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a token whose audience does not match the app's bundle id", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey, { audience: "com.someoneelse.otherapp" });

    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: token }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a token whose issuer is not Apple", async () => {
    const { privateKey, publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const token = await signValidToken(privateKey, { issuer: "https://evil.example.com" });

    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: token }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("rejects an RS256-to-HS256 algorithm-confusion token, even with a matching kid and claims", async () => {
    const { publicJwk } = await buildTestKeyPair();
    stubJwksFetch([publicJwk]);
    const forgedToken = forgeAlgorithmConfusionToken(KID, publicJwk.n as string);

    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ identityToken: forgedToken }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("returns 400 rather than 500 for a missing request body", async () => {
    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: undefined }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("returns 400 rather than 500 for a malformed JSON body", async () => {
    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: "{not json" }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("returns 400 rather than 500 when identityToken is absent from an otherwise valid body", async () => {
    const { handler, docClient } = await loadHandler();
    mockClient(docClient);

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ displayName: "No Token" }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });
});
