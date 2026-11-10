import { describe, expect, test } from "bun:test";
import { findMathSpans } from "../lib/spans.ts";

describe("findMathSpans", () => {
  test("1 つの数式を $ ごと範囲に含める", () => {
    expect(findMathSpans("配点 : $100$ 点")).toEqual([{ start: 5, end: 10, tex: "100" }]);
  });

  test("1 行に複数ある数式を順に返す", () => {
    expect(findMathSpans("$N$ 人に $1, 2, \\ldots, N$ と")).toEqual([
      { start: 0, end: 3, tex: "N" },
      { start: 7, end: 24, tex: "1, 2, \\ldots, N" },
    ]);
  });

  test("$$...$$ は 1 つの数式として扱う", () => {
    expect(findMathSpans("$$a + b$$")).toEqual([{ start: 0, end: 9, tex: "a + b" }]);
  });

  test.each([
    ["金額の表記", "It costs $5 and $10 in total"],
    ["開きの直後が空白", "a $ x$ b"],
    ["閉じの直前が空白", "a $x $ b"],
    ["閉じが無い", "price is $5"],
    ["中身が空", "a $$ b"],
    ["インラインコードの中", "run `echo $HOME$` now"],
    ["エスケープされた $", "\\$x\\$"],
  ])("%s は数式にしない", (_name, line) => {
    expect(findMathSpans(line)).toEqual([]);
  });

  test("インラインコードの後ろにある数式は拾う", () => {
    expect(findMathSpans("`$a$` と $b$")).toEqual([{ start: 8, end: 11, tex: "b" }]);
  });
});