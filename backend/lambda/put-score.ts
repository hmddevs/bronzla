import type { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import { docClient, encodeScoreSortKey } from "./shared/dynamo";
import { InvalidDisplayNameError, sanitizeDisplayName } from "./shared/display-name";
import { resolveSession, SessionAuthError } from "./shared/session-auth";
import { hashAppleSub, logger } from "./shared/logger";

const SESSIONS_TABLE = process.env.SESSIONS_TABLE_NAME ?? "";
const SCORES_TABLE = process.env.SCORES_TABLE_NAME ?? "";
const USERS_TABLE = process.env.USERS_TABLE_NAME ?? "";

const MAX_DISPLAY_NAME_LENGTH = 60;
// Client-supplied score; cap generously above any plausible in-app score so
// a malformed or malicious client cannot pollute the leaderboard sort key.
const MAX_SCORE_VALUE = 1_000_000;

interface PutScoreRequestBody {
  displayName: string;
  score: number;
}

function parseRequestBody(rawBody: string | undefined): PutScoreRequestBody {
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

  if (typeof body.displayName !== "string") {
    throw new TypeError("displayName is required and must be a string");
  }
  const trimmedDisplayName = body.displayName.trim();
  if (trimmedDisplayName.length === 0) {
    throw new TypeError("displayName is required and must not be blank");
  }
  if (trimmedDisplayName.length > MAX_DISPLAY_NAME_LENGTH) {
    throw new TypeError(`displayName must be at most ${MAX_DISPLAY_NAME_LENGTH} characters`);
  }
  if (typeof body.score !== "number" || !Number.isInteger(body.score) || body.score < 0) {
    throw new TypeError("score must be a non-negative integer");
  }
  if (body.score > MAX_SCORE_VALUE) {
    throw new TypeError(`score must be at most ${MAX_SCORE_VALUE}`);
  }

  let sanitizedDisplayName: string;
  try {
    sanitizedDisplayName = sanitizeDisplayName(trimmedDisplayName);
  } catch (error) {
    if (error instanceof InvalidDisplayNameError) {
      throw new TypeError(error.message);
    }
    throw error;
  }

  return { displayName: sanitizedDisplayName, score: body.score };
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

  let requestBody: PutScoreRequestBody;
  try {
    requestBody = parseRequestBody(event.body);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "invalid request";
    logger.warn("put-score rejected: bad body", {
      operation: "putScore",
      requestId,
      appleSubHash: hashAppleSub(session.appleSub),
      reason,
    });
    return { statusCode: 400, body: JSON.stringify({ error: reason }) };
  }

  try {
    await docClient.send(
      new PutCommand({
        TableName: SCORES_TABLE,
        Item: {
          appleSub: session.appleSub,
          leaderboardScope: "global",
          scoreSortKey: encodeScoreSortKey(requestBody.score),
          displayName: requestBody.displayName,
          score: requestBody.score,
          updatedAt: new Date().toISOString(),
        },
      })
    );

    logger.info("score updated", {
      operation: "putScore",
      requestId,
      appleSubHash: hashAppleSub(session.appleSub),
    });

    return { statusCode: 204, body: "" };
  } catch (error) {
    logger.error("put-score failed", {
      operation: "putScore",
      requestId,
      appleSubHash: hashAppleSub(session.appleSub),
      reason: error instanceof Error ? error.message : "unknown error",
    });
    return { statusCode: 500, body: JSON.stringify({ error: "internal error" }) };
  }
};
