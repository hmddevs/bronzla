import { describe, expect, it } from "vitest";
import { InvalidDisplayNameError, sanitizeDisplayName } from "../lambda/shared/display-name";

describe("sanitizeDisplayName", () => {
  it("rejects a name containing a zero-width character", () => {
    expect(() => sanitizeDisplayName("Test​User")).toThrow(InvalidDisplayNameError);
  });

  it("rejects a name containing a bidi override character", () => {
    expect(() => sanitizeDisplayName("Test‮User")).toThrow(InvalidDisplayNameError);
  });

  it("rejects a name containing a C0 control character", () => {
    expect(() => sanitizeDisplayName("TestUser")).toThrow(InvalidDisplayNameError);
  });

  it("rejects a name containing a C1 control character", () => {
    expect(() => sanitizeDisplayName("TestUser")).toThrow(InvalidDisplayNameError);
  });

  it("accepts a normal Unicode name with accented Latin characters", () => {
    expect(sanitizeDisplayName("François")).toBe("François");
  });

  it("accepts a normal Unicode name with Turkish characters", () => {
    expect(sanitizeDisplayName("Ümüt Güdeş")).toBe("Ümüt Güdeş");
  });

  it("accepts a normal Unicode name with CJK characters", () => {
    expect(sanitizeDisplayName("田中太郎")).toBe("田中太郎");
  });

  it("normalises an NFD-encoded input to NFC before returning it", () => {
    const nfd = "Café"; // "e" + combining acute accent, decomposed form
    const nfc = "Café"; // precomposed form
    expect(nfd).not.toBe(nfc);
    expect(sanitizeDisplayName(nfd)).toBe(nfc);
  });
});
