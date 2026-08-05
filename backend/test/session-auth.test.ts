import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "../lambda/shared/dynamo";
import { resolveSession, SessionAuthError } from "../lambda/shared/session-auth";

const ddbMock = mockClient(docClient);

const SESSIONS_TABLE = "BronzlaSessions-test";
const USERS_TABLE = "BronzlaUsers-test";

describe("resolveSession", () => {
  beforeEach(() => {
    ddbMock.reset();
  });

  it("resolves a valid, unexpired session for an existing user", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: { appleSub: "sub-1" } });

    const result = await resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1");

    expect(result).toEqual({ appleSub: "sub-1", sessionToken: "tok" });
  });

  it("performs the Users existence check with ConsistentRead", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: { appleSub: "sub-1" } });

    await resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1");

    const usersCall = ddbMock
      .commandCalls(GetCommand)
      .find((call) => call.args[0].input.TableName === USERS_TABLE);
    expect(usersCall?.args[0].input.ConsistentRead).toBe(true);
  });

  it("rejects a session whose user row no longer exists, even though the session row is valid", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: undefined });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects when expiresAt is missing from the session record, rather than failing open", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1" },
    });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects when expiresAt is not a number", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1", expiresAt: "not-a-number" },
    });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects an expired session", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionToken: "tok", appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) - 10 },
    });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects an unknown session token", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({ Item: undefined });

    await expect(
      resolveSession("Bearer unknown", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects a missing or malformed Authorization header", async () => {
    await expect(
      resolveSession(undefined, docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
    await expect(
      resolveSession("NotBearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });
});
