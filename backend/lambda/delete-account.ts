import type { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { QueryCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "./shared/dynamo";
import { resolveSession, SessionAuthError } from "./shared/session-auth";
import { hashAppleSub, logger } from "./shared/logger";

const USERS_TABLE = process.env.USERS_TABLE_NAME ?? "";
const SESSIONS_TABLE = process.env.SESSIONS_TABLE_NAME ?? "";
const SCORES_TABLE = process.env.SCORES_TABLE_NAME ?? "";
const SESSIONS_BY_APPLE_SUB_GSI_NAME = process.env.SESSIONS_BY_APPLE_SUB_GSI_NAME ?? "";

// DynamoDB TransactWriteItems caps a single transaction at 100 write items.
// Sessions are deleted first, in batches, and the User + Score rows are
// deleted last in a single final transaction. This ordering is deliberate,
// not cosmetic: while the user row still exists, a stale bearer token found
// by a lagging GSI read remains "live" from an authorisation standpoint
// (resolveSession's existence check would still find the user and let the
// request through). Deleting every session first, then the user, means
// that by the time the user row disappears there is no session left to
// look up in the first place — belt and braces alongside the existence
// check in shared/session-auth.ts. If a later step fails the caller sees a
// 500 and can safely retry: re-querying and re-deleting sessions is
// idempotent, and the final transaction only ever runs once the account is
// otherwise already gone from the caller's perspective.
const MAX_SESSION_DELETES_PER_TRANSACTION = 100;

async function fetchAllSessionTokenHashes(appleSub: string): Promise<string[]> {
  const tokenHashes: string[] = [];
  let lastEvaluatedKey: Record<string, unknown> | undefined;

  do {
    const result = await docClient.send(
      new QueryCommand({
        TableName: SESSIONS_TABLE,
        IndexName: SESSIONS_BY_APPLE_SUB_GSI_NAME,
        KeyConditionExpression: "appleSub = :appleSub",
        ExpressionAttributeValues: { ":appleSub": appleSub },
        ProjectionExpression: "sessionTokenHash",
        ExclusiveStartKey: lastEvaluatedKey,
      })
    );
    for (const item of result.Items ?? []) {
      tokenHashes.push(item.sessionTokenHash as string);
    }
    lastEvaluatedKey = result.LastEvaluatedKey as Record<string, unknown> | undefined;
  } while (lastEvaluatedKey);

  return tokenHashes;
}

function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const requestId = event.requestContext.requestId;

  let session;
  try {
    session = await resolveSession(
      event.headers?.authorization ?? event.headers?.Authorization,
      docClient,
      SESSIONS_TABLE,
      USERS_TABLE,
      requestId
    );
  } catch (error) {
    if (error instanceof SessionAuthError) {
      return { statusCode: 401, body: JSON.stringify({ error: "unauthorised" }) };
    }
    throw error;
  }

  const { appleSub, sessionTokenHash: presentedSessionTokenHash } = session;

  try {
    const queriedTokenHashes = await fetchAllSessionTokenHashes(appleSub);
    // Always include the session actually presented on this request, even if
    // the (eventually consistent) GSI query missed it: otherwise a session
    // created just before deletion could survive as a live bearer token.
    const sessionTokenHashes = Array.from(new Set([...queriedTokenHashes, presentedSessionTokenHash]));
    const sessionBatches = chunk(sessionTokenHashes, MAX_SESSION_DELETES_PER_TRANSACTION);

    // Delete every session batch first, each atomically per batch, before
    // the account itself disappears (see comment on
    // MAX_SESSION_DELETES_PER_TRANSACTION for why this ordering matters).
    for (const batch of sessionBatches) {
      await docClient.send(
        new TransactWriteCommand({
          TransactItems: batch.map((sessionTokenHash) => ({
            Delete: { TableName: SESSIONS_TABLE, Key: { sessionTokenHash } },
          })),
        })
      );
    }

    // Final transaction: User + Score, deleted together once every known
    // session has already been removed.
    await docClient.send(
      new TransactWriteCommand({
        TransactItems: [
          { Delete: { TableName: USERS_TABLE, Key: { appleSub } } },
          { Delete: { TableName: SCORES_TABLE, Key: { appleSub } } },
        ],
      })
    );

    logger.info("account deleted", {
      operation: "deleteAccount",
      requestId,
      appleSubHash: hashAppleSub(appleSub),
      sessionsDeleted: sessionTokenHashes.length,
    });

    return { statusCode: 204, body: "" };
  } catch (error) {
    logger.error("delete-account failed", {
      operation: "deleteAccount",
      requestId,
      appleSubHash: hashAppleSub(appleSub),
      reason: error instanceof Error ? error.message : "unknown error",
    });
    return { statusCode: 500, body: JSON.stringify({ error: "internal error" }) };
  }
};
