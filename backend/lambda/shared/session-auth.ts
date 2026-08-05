import { GetCommand, type DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { hashAppleSub, logger } from "./logger";

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
   * The raw bearer token used for this request. Callers that delete a
   * session on the caller's behalf (delete-account) must include this
   * exact token in their deletion set: the GSI used to enumerate a user's
   * sessions is eventually consistent and can miss a session created just
   * before deletion, so the token actually presented on the request must
   * always be deleted too, not just whatever the GSI query happens to see.
   */
  sessionToken: string;
}

interface SessionRecord {
  sessionToken: string;
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

  const result = await docClient.send(
    new GetCommand({
      TableName: sessionsTableName,
      Key: { sessionToken },
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

  return { appleSub: session.appleSub, sessionToken };
}
