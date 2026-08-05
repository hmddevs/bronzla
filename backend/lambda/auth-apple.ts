import type { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { randomBytes } from "node:crypto";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "./shared/dynamo";
import { AppleTokenVerificationError, verifyAppleIdentityToken } from "./shared/apple-jwt";
import { InvalidDisplayNameError, sanitizeDisplayName } from "./shared/display-name";
import { hashSessionToken } from "./shared/session-auth";
import { hashAppleSub, logger } from "./shared/logger";

const USERS_TABLE = process.env.USERS_TABLE_NAME ?? "";
const SESSIONS_TABLE = process.env.SESSIONS_TABLE_NAME ?? "";
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID ?? "";

// Fails at cold start rather than per-request: an empty bundle ID passed as
// `audience` into jose's jwtVerify is never actually checked (jose only
// compares `aud` when the option is truthy), which would let a validly
// Apple-signed token for ANY app be accepted here.
if (APPLE_BUNDLE_ID.length === 0) {
  throw new Error("APPLE_BUNDLE_ID environment variable is required and must be non-empty");
}

const SESSION_TTL_SECONDS = 90 * 24 * 60 * 60;
const MAX_DISPLAY_NAME_LENGTH = 60;

interface AuthAppleRequestBody {
  identityToken: string;
  displayName?: string;
}

function parseRequestBody(rawBody: string | undefined): AuthAppleRequestBody {
  if (!rawBody) {
    throw new TypeError("request body is required");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    throw new TypeError("request body is not valid JSON");
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new TypeError("request body must be a JSON object");
  }
  const body = parsed as Record<string, unknown>;
  if (typeof body.identityToken !== "string" || body.identityToken.length === 0) {
    throw new TypeError("identityToken is required and must be a string");
  }
  if (body.displayName !== undefined) {
    if (typeof body.displayName !== "string" || body.displayName.length === 0) {
      throw new TypeError("displayName must be a non-empty string when provided");
    }
    if (body.displayName.length > MAX_DISPLAY_NAME_LENGTH) {
      throw new TypeError(`displayName must be at most ${MAX_DISPLAY_NAME_LENGTH} characters`);
    }
  }
  const displayName =
    body.displayName !== undefined
      ? (() => {
          try {
            return sanitizeDisplayName(body.displayName as string);
          } catch (error) {
            if (error instanceof InvalidDisplayNameError) {
              throw new TypeError(error.message);
            }
            throw error;
          }
        })()
      : undefined;
  return { identityToken: body.identityToken, displayName };
}

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const requestId = event.requestContext.requestId;

  let requestBody: AuthAppleRequestBody;
  try {
    requestBody = parseRequestBody(event.body);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "invalid request";
    logger.warn("auth request rejected: bad body", { operation: "authApple", requestId, reason });
    return { statusCode: 400, body: JSON.stringify({ error: reason }) };
  }

  let verified: { sub: string };
  try {
    verified = await verifyAppleIdentityToken(requestBody.identityToken, APPLE_BUNDLE_ID);
  } catch (error) {
    const reason = error instanceof AppleTokenVerificationError ? error.message : "verification failed";
    logger.warn("apple token verification failed", { operation: "authApple", requestId, reason });
    return { statusCode: 401, body: JSON.stringify({ error: "invalid identity token" }) };
  }

  const appleSub = verified.sub;

  try {
    const existing = await docClient.send(
      new GetCommand({ TableName: USERS_TABLE, Key: { appleSub } })
    );

    const nowIso = new Date().toISOString();
    const createdAt = (existing.Item?.createdAt as string | undefined) ?? nowIso;
    const displayName =
      requestBody.displayName ?? (existing.Item?.displayName as string | undefined) ?? "";

    await docClient.send(
      new PutCommand({
        TableName: USERS_TABLE,
        Item: { appleSub, displayName, createdAt },
      })
    );

    // The raw token leaves this function exactly once, in the response body
    // below. Only its SHA-256 is persisted, so a read of the Sessions table
    // gives an attacker nothing they can present as a bearer token. See
    // hashSessionToken in shared/session-auth.ts for why a plain hash rather
    // than a password KDF is the correct choice for a 256-bit random secret.
    const sessionToken = randomBytes(32).toString("base64url");
    const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS;

    await docClient.send(
      new PutCommand({
        TableName: SESSIONS_TABLE,
        Item: { sessionTokenHash: hashSessionToken(sessionToken), appleSub, expiresAt },
      })
    );

    logger.info("auth succeeded", { operation: "authApple", requestId, appleSubHash: hashAppleSub(appleSub) });

    return {
      statusCode: 200,
      body: JSON.stringify({ sessionToken, displayName }),
    };
  } catch (error) {
    logger.error("auth request failed after token verification", {
      operation: "authApple",
      requestId,
      appleSubHash: hashAppleSub(appleSub),
      reason: error instanceof Error ? error.message : "unknown error",
    });
    return { statusCode: 500, body: JSON.stringify({ error: "internal error" }) };
  }
};
