import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand, QueryCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { docClient } from "../lambda/shared/dynamo";
import { hashSessionToken } from "../lambda/shared/session-auth";
import { handler } from "../lambda/delete-account";

// Table/GSI names are set in vitest.config.ts (test.env), applied before
// any module import, so the handler's module-level env reads see them.
const ddbMock = mockClient(docClient);

function buildEvent(overrides: Partial<APIGatewayProxyEventV2> = {}): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "DELETE /account",
    rawPath: "/account",
    rawQueryString: "",
    headers: { authorization: "Bearer valid-session-token" },
    requestContext: {
      requestId: "test-request-id",
    } as APIGatewayProxyEventV2["requestContext"],
    isBase64Encoded: false,
    ...overrides,
  } as APIGatewayProxyEventV2;
}

describe("delete-account handler", () => {
  beforeEach(() => {
    ddbMock.reset();
    ddbMock.on(GetCommand, { TableName: "BronzlaSessions-test" }).resolves({
      Item: {
        sessionTokenHash: hashSessionToken("valid-session-token"),
        appleSub: "sub-1",
        expiresAt: Math.floor(Date.now() / 1000) + 1000,
      },
    });
    ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({
      Item: { appleSub: "sub-1", displayName: "Test User", createdAt: "2026-01-01T00:00:00.000Z" },
    });
  });

  it("deletes every session first, then the user and score in a final transaction", async () => {
    ddbMock.on(QueryCommand).resolves({
      Items: [
        { sessionTokenHash: hashSessionToken("valid-session-token") },
        { sessionTokenHash: hashSessionToken("other-device-token") },
      ],
    });
    ddbMock.on(TransactWriteCommand).resolves({});

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(204);
    const transactCalls = ddbMock.commandCalls(TransactWriteCommand);
    expect(transactCalls).toHaveLength(2);

    // First transaction: sessions only.
    const sessionTransactItems = transactCalls[0]?.args[0].input.TransactItems ?? [];
    expect(sessionTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaSessions-test", Key: { sessionTokenHash: hashSessionToken("valid-session-token") } },
    });
    expect(sessionTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaSessions-test", Key: { sessionTokenHash: hashSessionToken("other-device-token") } },
    });
    expect(sessionTransactItems.every((item) => "Delete" in item && item.Delete?.TableName === "BronzlaSessions-test")).toBe(
      true
    );

    // Final transaction: User + Score only, run after every session is gone.
    const finalTransactItems = transactCalls[1]?.args[0].input.TransactItems ?? [];
    expect(finalTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaUsers-test", Key: { appleSub: "sub-1" } },
    });
    expect(finalTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaScores-test", Key: { appleSub: "sub-1" } },
    });
  });

  it("deletes the presented session token even if the GSI query misses it", async () => {
    // Simulates GSI replication lag: the query returns no rows at all, but
    // the token used to authenticate this very request must still be
    // deleted so it cannot be reused.
    ddbMock.on(QueryCommand).resolves({ Items: [] });
    ddbMock.on(TransactWriteCommand).resolves({});

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(204);
    const transactCalls = ddbMock.commandCalls(TransactWriteCommand);
    const sessionTransactItems = transactCalls[0]?.args[0].input.TransactItems ?? [];
    expect(sessionTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaSessions-test", Key: { sessionTokenHash: hashSessionToken("valid-session-token") } },
    });
  });

  it("paginates the session-token query across multiple pages before deleting", async () => {
    ddbMock
      .on(QueryCommand)
      .resolvesOnce({
        Items: [{ sessionTokenHash: "hash-page-1" }],
        LastEvaluatedKey: { sessionTokenHash: "hash-page-1" },
      })
      .resolvesOnce({ Items: [{ sessionTokenHash: "hash-page-2" }] });
    ddbMock.on(TransactWriteCommand).resolves({});

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(204);
    expect(ddbMock.commandCalls(QueryCommand)).toHaveLength(2);
    const sessionTransactItems = ddbMock.commandCalls(TransactWriteCommand)[0]?.args[0].input.TransactItems ?? [];
    expect(sessionTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaSessions-test", Key: { sessionTokenHash: "hash-page-1" } },
    });
    expect(sessionTransactItems).toContainEqual({
      Delete: { TableName: "BronzlaSessions-test", Key: { sessionTokenHash: "hash-page-2" } },
    });
  });

  it("rejects an unauthenticated request without touching the tables", async () => {
    const response = (await handler(
      buildEvent({ headers: {} }),
      {} as never,
      undefined as never
    )) as { statusCode: number };

    expect(response.statusCode).toBe(401);
    expect(ddbMock.commandCalls(TransactWriteCommand)).toHaveLength(0);
  });

  it("rejects a session whose user row no longer exists, without touching the tables", async () => {
    ddbMock.on(GetCommand, { TableName: "BronzlaUsers-test" }).resolves({ Item: undefined });

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(401);
    expect(ddbMock.commandCalls(TransactWriteCommand)).toHaveLength(0);
  });

  it("returns 500 and reports no success if the transaction fails", async () => {
    ddbMock.on(QueryCommand).resolves({ Items: [] });
    ddbMock.on(TransactWriteCommand).rejects(new Error("transaction cancelled"));

    const response = (await handler(buildEvent(), {} as never, undefined as never)) as {
      statusCode: number;
    };

    expect(response.statusCode).toBe(500);
  });
});
