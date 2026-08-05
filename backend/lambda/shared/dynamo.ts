import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

const rawClient = new DynamoDBClient({});

export const docClient = DynamoDBDocumentClient.from(rawClient, {
  marshallOptions: { removeUndefinedValues: true },
});

/**
 * Score sort key encoding for the leaderboard GSI: zero-padded to a fixed
 * width and lexicographically inverted (MAX_SCORE - score), so that a plain
 * ascending sort-key query returns highest scores first without needing a
 * ScanIndexForward: false query option to be remembered at every call site.
 * MAX_SCORE comfortably exceeds the 1,000,000 application-level score cap.
 */
export const MAX_SCORE = 10_000_000;
export const SCORE_SORT_KEY_WIDTH = 8;

export function encodeScoreSortKey(score: number): string {
  return String(MAX_SCORE - score).padStart(SCORE_SORT_KEY_WIDTH, "0");
}
