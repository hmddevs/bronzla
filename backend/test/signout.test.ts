import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { DeleteCommand, GetCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { docClient } from "../lambda/shared/dynamo";
import { hashSessionToken, resolveSession, SessionAuthError } from "../lambda/shared/session-auth";
import { handler } from "../lambda/signout";

// Table names are set in vitest.config.ts (test.env), applied before any
// module import, so the handler's module-level env reads see them.
const ddbMock = mockClient(docClient);

const SESSIONS_TABLE = "BronzlaSessions-test";
const USERS_TABLE = "BronzlaUsers-test";
const RAW_TOKEN = "valid-session-token";

function buildEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "POST /auth/signout",
    rawPath: "/auth/signout",
    rawQueryString: "",
    headers: { authorization: `Bearer ${RAW_TOKEN}` },
    requestContext: {
      requestId: "test-request-id",
    } as APIGatewayProxyEventV2["requestContext"],
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

function stubLiveSession(): void {
  ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
    Item: {
      sessionTokenHash: hashSessionToken(RAW_TOKEN),
      appleSub: "sub-1",
      expiresAt: Math.floor(Date.now() / 1000) + 1000,
    },
  });
  ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({
    Item: { appleSub: "sub-1", displayName: "Test User", createdAt: "2026-01-01T00:00:00.000Z" },
  });
}

describe("signout handler", () => {
  beforeEach(() => {
    ddbMock.reset();
    stubLiveSession();
  });

  it("deletes the calling session, keyed on the token hash", async () => {
    ddbMock.on(DeleteCommand).resolves({});

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(204);
    const deleteCalls = ddbMock.commandCalls(DeleteCommand);
    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0]?.args[0].input).toMatchObject({
      TableName: SESSIONS_TABLE,
      Key: { sessionTokenHash: hashSessionToken(RAW_TOKEN) },
    });
    // The raw bearer token must never appear in the delete key.
    expect(JSON.stringify(deleteCalls[0]?.args[0].input.Key)).not.toContain(RAW_TOKEN);
  });

  it("rejects a token that has already been signed out", async () => {
    ddbMock.on(DeleteCommand).resolves({});

    const first = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };
    expect(first.statusCode).toBe(204);

    // The row is now gone, so the very next request presenting the same token
    // fails to resolve rather than being honoured for the rest of the TTL.
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({ Item: undefined });

    await expect(
      resolveSession(`Bearer ${RAW_TOKEN}`, docClient, SESSIONS_TABLE, USERS_TABLE, "req-2")
    ).rejects.toBeInstanceOf(SessionAuthError);

    const second = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };
    expect(second.statusCode).toBe(401);
    // No second delete: the 401 short-circuits before any write.
    expect(ddbMock.commandCalls(DeleteCommand)).toHaveLength(1);
  });

  it("revokes only the calling session, never enumerating the user's others", async () => {
    ddbMock.on(DeleteCommand).resolves({});

    await handler(buildEvent(), {} as never, undefined as never);

    const deleteCalls = ddbMock.commandCalls(DeleteCommand);
    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0]?.args[0].input.Key).toEqual({
      sessionTokenHash: hashSessionToken(RAW_TOKEN),
    });
  });

  it("rejects an unauthenticated request without deleting anything", async () => {
    const response = (await handler(
      buildEvent({ headers: {} }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
    expect(ddbMock.commandCalls(DeleteCommand)).toHaveLength(0);
  });

  it("rejects an expired session without deleting anything", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: {
        sessionTokenHash: hashSessionToken(RAW_TOKEN),
        appleSub: "sub-1",
        expiresAt: Math.floor(Date.now() / 1000) - 10,
      },
    });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
    expect(ddbMock.commandCalls(DeleteCommand)).toHaveLength(0);
  });

  it("returns 500 rather than a false 204 if the delete fails", async () => {
    ddbMock.on(DeleteCommand).rejects(new Error("throttled"));

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(500);
  });
});
