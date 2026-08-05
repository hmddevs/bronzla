import type { APIGatewayProxyHandlerV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "./shared/dynamo";
import { resolveSession, SessionAuthError } from "./shared/session-auth";
import { logger } from "./shared/logger";

const SESSIONS_TABLE = process.env.SESSIONS_TABLE_NAME ?? "";
const SCORES_TABLE = process.env.SCORES_TABLE_NAME ?? "";
const USERS_TABLE = process.env.USERS_TABLE_NAME ?? "";
const LEADERBOARD_GSI_NAME = process.env.LEADERBOARD_GSI_NAME ?? "";

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

function parseLimit(rawLimit: string | undefined): number {
  if (rawLimit === undefined) {
    return DEFAULT_LIMIT;
  }
  const parsed = Number(rawLimit);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new TypeError("limit must be a positive integer");
  }
  return Math.min(parsed, MAX_LIMIT);
}

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const requestId = event.requestContext.requestId;

  try {
    await resolveSession(
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

  let limit: number;
  try {
    limit = parseLimit(event.queryStringParameters?.limit);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "invalid request";
    return { statusCode: 400, body: JSON.stringify({ error: reason }) };
  }

  try {
    const result = await docClient.send(
      new QueryCommand({
        TableName: SCORES_TABLE,
        IndexName: LEADERBOARD_GSI_NAME,
        KeyConditionExpression: "leaderboardScope = :scope",
        ExpressionAttributeValues: { ":scope": "global" },
        // Ascending on the inverted sort key yields descending score order.
        ScanIndexForward: true,
        Limit: limit,
      })
    );

    // Hard privacy requirement: never include appleSub in the response body
    // or in any log line touching this response.
    const items = (result.Items ?? []).map((item) => ({
      displayName: item.displayName as string,
      score: item.score as number,
    }));

    logger.info("leaderboard served", { operation: "getLeaderboard", requestId, count: items.length });

    return { statusCode: 200, body: JSON.stringify(items) };
  } catch (error) {
    logger.error("get-leaderboard failed", {
      operation: "getLeaderboard",
      requestId,
      reason: error instanceof Error ? error.message : "unknown error",
    });
    return { statusCode: 500, body: JSON.stringify({ error: "internal error" }) };
  }
};
