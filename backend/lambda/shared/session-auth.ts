import { createHash } from "node:crypto";
import { GetCommand, type DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { hashAppleSub, logger } from "./logger";

/**
 * Hashes a raw session token into the value actually stored as the Sessions
 * table partition key. The raw token is handed to the client exactly once, at
 * sign-in, and is never persisted server-side, so a read of the Sessions table
 * yields nothing replayable.
 *
 * A single unsalted SHA-256 is the right primitive here, and deliberately not
 * bcrypt, scrypt or Argon2. Those exist to make low-entropy, guessable secrets
 * (passwords) expensive to attack offline. A session token is 32 bytes from
 * the CSPRNG, so there is no guessing space to defend and no dictionary to
 * slow down. A deliberately slow KDF would add its cost to every single
 * authenticated request while buying nothing. Salting is likewise pointless:
 * the input is already unique and unguessable, so there are no rainbow tables
 * to defeat, and a per-row salt would make the lookup impossible anyway
 * because we must derive the key from the presented token alone.
 */
export function hashSessionToken(rawToken: string): string {
  return createHash("sha256").update(rawToken).digest("hex");
}

/**
 * Resolves an `Authorization: Bearer <sessionToken>` header to an appleSub.
 *
 * Implemented as a plain function imported by each handler rather than a
 * separate API Gateway Lambda authoriser resource: at this stack's size
 * (four routes) a dedicated authoriser Lambda plus its own IAM role and
 * caching configuration is more moving parts than it saves, and inlining
 * keeps the auth failure path easy to step through in one file per handler.
 *
 * DynamoDB TTL deletion of expired sessions is eventually consistent and
 * can lag well behind `expiresAt`, so `expiresAt` is checked explicitly here
 * rather than trusting TTL as the security boundary.
 *
 * A session token surviving account deletion is a second lag hazard: the
 * `SessionsByAppleSub` GSI used by delete-account is also eventually
 * consistent, so a session created concurrently with a deletion could
 * outlive the user row it points to. To make any such stale token inert
 * regardless of GSI lag, every resolution re-confirms the user still exists
 * with a strongly consistent read against the Users table.
 */

export class SessionAuthError extends Error {
  readonly statusCode = 401;
}

export interface AuthorisedSession {
  appleSub: string;
  /**
   * SHA-256 of the bearer token presented on this request, which is also the
   * Sessions table partition key. Deliberately not the raw token: nothing
   * downstream of authentication has any need for it, and handlers that
   * delete a session (signout, delete-account) key on the hash directly.
   *
   * delete-account must include this exact value in its deletion set: the
   * GSI used to enumerate a user's sessions is eventually consistent and can
   * miss a session created just before deletion, so the session actually
   * presented on the request must always be deleted too, not just whatever
   * the GSI query happens to see.
   */
  sessionTokenHash: string;
}

interface SessionRecord {
  sessionTokenHash: string;
  appleSub: string;
  expiresAt: number;
}

export async function resolveSession(
  authorizationHeader: string | undefined,
  docClient: DynamoDBDocumentClient,
  sessionsTableName: string,
  usersTableName: string,
  requestId: string
): Promise<AuthorisedSession> {
  if (!authorizationHeader || !authorizationHeader.startsWith("Bearer ")) {
    throw new SessionAuthError("missing or malformed Authorization header");
  }

  const sessionToken = authorizationHeader.slice("Bearer ".length).trim();
  if (sessionToken.length === 0) {
    throw new SessionAuthError("empty session token");
  }

  // Look up by hash, never by the raw token: the raw value is not stored.
  const sessionTokenHash = hashSessionToken(sessionToken);

  const result = await docClient.send(
    new GetCommand({
      TableName: sessionsTableName,
      Key: { sessionTokenHash },
    })
  );

  const session = result.Item as SessionRecord | undefined;
  if (!session) {
    logger.warn("session lookup failed: unknown token", { operation: "resolveSession", requestId });
    throw new SessionAuthError("unknown session token");
  }

  if (typeof session.appleSub !== "string" || session.appleSub.length === 0) {
    logger.warn("session lookup failed: malformed session record (appleSub)", {
      operation: "resolveSession",
      requestId,
    });
    throw new SessionAuthError("malformed session record");
  }

  const nowEpochSeconds = Math.floor(Date.now() / 1000);
  if (typeof session.expiresAt !== "number" || session.expiresAt <= nowEpochSeconds) {
    logger.warn("session lookup failed: expired or malformed token", {
      operation: "resolveSession",
      requestId,
      appleSubHash: hashAppleSub(session.appleSub),
    });
    throw new SessionAuthError("expired session token");
  }

  // Authoritative existence check: a strongly consistent read protects
  // against a session outliving its user row due to GSI replication lag
  // during account deletion (see module doc comment above).
  const userResult = await docClient.send(
    new GetCommand({
      TableName: usersTableName,
      Key: { appleSub: session.appleSub },
      ConsistentRead: true,
    })
  );

  if (!userResult.Item) {
    logger.warn("session lookup failed: user no longer exists", {
      operation: "resolveSession",
      requestId,
      appleSubHash: hashAppleSub(session.appleSub),
    });
    throw new SessionAuthError("session refers to a deleted user");
  }

  return { appleSub: session.appleSub, sessionTokenHash };
}
