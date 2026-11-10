import { describe, expect, test } from "bun:test";
import { utf8ByteLength } from "../lib/utf8.ts";

describe("utf8ByteLength", () => {
  test.each([
    ["abc", 3],
    ["配点 : ", 9],
    ["α≤", 5],
    ["😀", 4],
  ])("%s は %d バイト", (text, bytes) => {
    expect(utf8ByteLength(text)).toBe(bytes);
  });
});
