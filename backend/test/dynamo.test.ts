import { describe, expect, it } from "vitest";
import { encodeScoreSortKey } from "../lambda/shared/dynamo";

describe("encodeScoreSortKey", () => {
  it("orders higher scores before lower scores lexicographically", () => {
    const low = encodeScoreSortKey(10);
    const high = encodeScoreSortKey(9000);

    // Ascending string comparison, as DynamoDB's own sort-key comparison
    // would perform, must place the higher score's key first.
    expect(high < low).toBe(true);
  });

  it("produces a fixed-width, zero-padded key", () => {
    const key = encodeScoreSortKey(0);
    expect(key).toHaveLength(8);
    expect(key).toMatch(/^\d{8}$/);
  });
});
