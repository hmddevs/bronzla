import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { docClient } from "../lambda/shared/dynamo";
import { handler } from "../lambda/get-leaderboard";

// Table/GSI names are set in vitest.config.ts (test.env), applied before
// any module import, so the handler's module-level env reads see them.
const ddbMock = mockClient(docClient);

function buildEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "GET /leaderboard",
    rawPath: "/leaderboard",
    rawQueryString: "",
    headers: { authorization: "Bearer valid-session-token" },
    queryStringParameters: undefined,
    requestContext: {
      requestId: "test-request-id",
    } as APIGatewayProxyEventV2["requestContext"],
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

describe("get-leaderboard handler", () => {
  beforeEach(() => {
    ddbMock.reset();
    ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
      Item: {
        sessionToken: "valid-session-token",
        appleSub: "sub-1",
        expiresAt: Math.floor(Date.now() / 1000) + 1000,
      },
    });
    ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({
      Item: { appleSub: "sub-1", displayName: "Test User", createdAt: "2026-01-01T00:00:00.000Z" },
    });
  });

  it("returns displayName and score only, never appleSub", async () => {
    ddbMock.on(QueryCommand).resolves({
      Items: [
        { appleSub: "sub-2", displayName: "Alice", score: 9000 },
        { appleSub: "sub-3", displayName: "Bob", score: 8000 },
      ],
    });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
      body: string;
    };

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body) as unknown[];
    expect(body).toEqual([
      { displayName: "Alice", score: 9000 },
      { displayName: "Bob", score: 8000 },
    ]);
    expect(response.body).not.toContain("appleSub");
    expect(response.body).not.toContain("sub-2");
  });

  it("clamps limit to the maximum allowed", async () => {
    ddbMock.on(QueryCommand).resolves({ Items: [] });

    await handler(
      buildEvent({ queryStringParameters: { limit: "500" } }),
      {} as never,
      undefined as never
    );

    const queryCalls = ddbMock.commandCalls(QueryCommand);
    expect(queryCalls[0]?.args[0].input.Limit).toBe(100);
  });

  it("rejects a session whose user row no longer exists", async () => {
    ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({ Item: undefined });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a non-integer limit", async () => {
    const response = (await handler(
      buildEvent({ queryStringParameters: { limit: "abc" } }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });
});
