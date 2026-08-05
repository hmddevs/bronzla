import { beforeEach, describe, expect, it } from "vitest";
import { mockClient } from "aws-sdk-client-mock";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { docClient } from "../lambda/shared/dynamo";
import { hashSessionToken, resolveSession, SessionAuthError } from "../lambda/shared/session-auth";

const ddbMock = mockClient(docClient);

const SESSIONS_TABLE = "BronzlaSessions-test";
const USERS_TABLE = "BronzlaUsers-test";

describe("resolveSession", () => {
  beforeEach(() => {
    ddbMock.reset();
  });

  it("resolves a valid, unexpired session for an existing user", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: { appleSub: "sub-1" } });

    const result = await resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1");

    expect(result).toEqual({ appleSub: "sub-1", sessionTokenHash: hashSessionToken("tok") });
  });

  it("performs the Users existence check with ConsistentRead", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
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
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: undefined });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects when expiresAt is missing from the session record, rather than failing open", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1" },
    });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects when expiresAt is not a number", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: "not-a-number" },
    });

    await expect(
      resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1")
    ).rejects.toBeInstanceOf(SessionAuthError);
  });

  it("rejects an expired session", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) - 10 },
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

  it("looks the session up by the token's SHA-256, never by the raw token", async () => {
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({
      Item: { sessionTokenHash: hashSessionToken("tok"), appleSub: "sub-1", expiresAt: Math.floor(Date.now() / 1000) + 1000 },
    });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: { appleSub: "sub-1" } });

    await resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1");

    const sessionsCall = ddbMock
      .commandCalls(GetCommand)
      .find((call) => call.args[0].input.TableName === SESSIONS_TABLE);
    expect(sessionsCall?.args[0].input.Key).toEqual({ sessionTokenHash: hashSessionToken("tok") });
    expect(JSON.stringify(sessionsCall?.args[0].input.Key)).not.toContain("tok\"");
  });

  it("produces a hash that is not the raw token and is stable for the same input", async () => {
    const hash = hashSessionToken("tok");
    expect(hash).not.toBe("tok");
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hashSessionToken("tok")).toBe(hash);
    expect(hashSessionToken("tok2")).not.toBe(hash);
  });

  it("rejects a raw token presented where only its hash is a valid key", async () => {
    // Models an attacker who has read the Sessions table and tries the stored
    // key material directly, and equally a client whose token was never
    // hashed: only the exact hash of the presented bearer token matches, so a
    // GetItem keyed on anything else finds nothing.
    // Broad stub first, exact-key stub second: aws-sdk-client-mock resolves
    // the most recently registered matching behaviour, so the specific key
    // must be registered after the catch-all to win.
    ddbMock.on(GetCommand, { TableName: SESSIONS_TABLE }).resolves({ Item: undefined });
    ddbMock
      .on(GetCommand, { TableName: SESSIONS_TABLE, Key: { sessionTokenHash: hashSessionToken("tok") } })
      .resolves({
        Item: {
          sessionTokenHash: hashSessionToken("tok"),
          appleSub: "sub-1",
          expiresAt: Math.floor(Date.now() / 1000) + 1000,
        },
      });
    ddbMock.on(GetCommand, { TableName: USERS_TABLE }).resolves({ Item: { appleSub: "sub-1" } });

    // The stored partition key itself is useless as a bearer token: presenting
    // it hashes again and misses.
    await expect(
      resolveSession(
        `Bearer ${hashSessionToken("tok")}`,
        docClient,
        SESSIONS_TABLE,
        USERS_TABLE,
        "req-1"
      )
    ).rejects.toBeInstanceOf(SessionAuthError);

    // The real raw token still works.
    const result = await resolveSession("Bearer tok", docClient, SESSIONS_TABLE, USERS_TABLE, "req-1");
    expect(result.appleSub).toBe("sub-1");
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
