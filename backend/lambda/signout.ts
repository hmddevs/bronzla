import type { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "./shared/dynamo";
import { resolveSession, SessionAuthError } from "./shared/session-auth";
import { hashAppleSub, logger } from "./shared/logger";

const SESSIONS_TABLE = process.env.SESSIONS_TABLE_NAME ?? "";
const USERS_TABLE = process.env.USERS_TABLE_NAME ?? "";

/**
 * Server-side session revocation. Sign out used to be purely client-side,
 * which meant a token lifted from the Keychain stayed valid for the whole
 * 90 day TTL no matter what the user did in the app. Deleting the row makes
 * the token inert immediately.
 *
 * Only the calling session is revoked, not every session for the user: the
 * other devices belong to the same person and signing out on one should not
 * silently sign them out everywhere. Revoking all of them is what
 * DELETE /account already does.
 */
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

  const { appleSub, sessionTokenHash } = session;

  try {
    // Idempotent by construction: DeleteItem on an absent key succeeds, so a
    // client retrying a signout it already completed still sees a 204.
    await docClient.send(
      new DeleteCommand({
        TableName: SESSIONS_TABLE,
        Key: { sessionTokenHash },
      })
    );

    logger.info("session revoked", {
      operation: "signout",
      requestId,
      appleSubHash: hashAppleSub(appleSub),
    });

    return { statusCode: 204, body: "" };
  } catch (error) {
    logger.error("signout failed", {
      operation: "signout",
      requestId,
      appleSubHash: hashAppleSub(appleSub),
      reason: error instanceof Error ? error.message : "unknown error",
    });
    return { statusCode: 500, body: JSON.stringify({ error: "internal error" }) };
  }
};
