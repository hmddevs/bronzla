import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { docClient } from "../lambda/shared/dynamo";
import { handler } from "../lambda/put-score";

// Table names are set in vitest.config.ts (test.env), applied before any
// module import, so the handler's module-level env reads see them.
const ddbMock = mockClient(docClient);

function buildEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "PUT /score",
    rawPath: "/score",
    rawQueryString: "",
    headers: { authorization: "Bearer valid-session-token" },
    requestContext: {
      requestId: "test-request-id",
    } as APIGatewayProxyEventV2["requestContext"],
    body: JSON.stringify({ displayName: "Test User", score: 100 }),
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

function mockValidSession(): void {
  ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
    Item: { sessionToken: "valid-session-token", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
  });
  ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({
    Item: { appleSub: "sub-1", displayName: "Test User", createdAt: "2026-01-01T00:00:00.000Z" },
  });
}

describe("put-score handler", () => {
  beforeEach(() => {
    ddbMock.reset();
  });

  it("upserts a score for an authenticated caller", async () => {
    mockValidSession();
    ddbMock.on(PutCommand).resolves({});

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(204);
    const putCalls = ddbMock.commandCalls(PutCommand);
    expect(putCalls).toHaveLength(1);
    expect(putCalls[0]?.args[0].input).toMatchObject({
      TableName: "BronzlaScores-test",
      Item: expect.objectContaining({ appleSub: "sub-1", score: 100, leaderboardScope: "global" }),
    });
  });

  it("rejects an expired session", async () => {
    ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
      Item: { sessionToken: "valid-session-token", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) - 10 },
    });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a session row missing expiresAt entirely, rather than failing open", async () => {
    ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
      Item: { sessionToken: "valid-session-token", appleSub: "sub-1" },
    });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a missing session token", async () => {
    const response = (await handler(
      buildEvent({ headers: {} }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
  });

  it("rejects a session whose user row no longer exists (stale token surviving account deletion)", async () => {
    ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
      Item: { sessionToken: "valid-session-token", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({ Item: undefined });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
    expect(ddbMock.commandCalls(PutCommand)).toHaveLength(0);
  });

  it("rejects a negative score", async () => {
    mockValidSession();

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ displayName: "Test User", score: -5 }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("rejects a score above the application-level cap", async () => {
    mockValidSession();

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ displayName: "Test User", score: 2_000_000 }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("rejects a fractional score, since it would break the fixed-width sort-key encoding", async () => {
    mockValidSession();

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ displayName: "Test User", score: 100.5 }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("rejects a whitespace-only displayName", async () => {
    mockValidSession();

    const response = (await handler(
      buildEvent({ body: JSON.stringify({ displayName: "   ", score: 100 }) }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(400);
  });

  it("trims displayName before storing it", async () => {
    mockValidSession();
    ddbMock.on(PutCommand).resolves({});

    await handler(
      buildEvent({ body: JSON.stringify({ displayName: "  Test User  ", score: 100 }) }),
      {} as never,
      undefined as never
    );

    const putCalls = ddbMock.commandCalls(PutCommand);
    expect(putCalls[0]?.args[0].input).toMatchObject({
      Item: expect.objectContaining({ displayName: "Test User" }),
    });
  });
});
