import { describe, expect, test } from "bun:test";
import { texToUnicode } from "../lib/tex.ts";

describe("texToUnicode: 記号コマンド", () => {
  test.each([
    ["1 \\leq N \\leq 100", "1 ≤ N ≤ 100"],
    ["a \\geq b", "a ≥ b"],
    ["a \\le b \\ge c", "a ≤ b ≥ c"],
    ["a \\neq b", "a ≠ b"],
    ["1, 2, \\ldots, N", "1, 2, …, N"],
    ["1 + \\cdots + N", "1 + ⋯ + N"],
    ["H \\times W", "H × W"],
    ["x \\in S", "x ∈ S"],
    ["a \\to b", "a → b"],
    ["\\lfloor x \\rfloor", "⌊ x ⌋"],
    ["a \\bmod b", "a mod b"],
    ["\\max(a, b)", "max(a, b)"],
    ["\\{1, 2\\}", "{1, 2}"],
    ["\\alpha + \\beta", "α + β"],
    ["\\angle ABC", "∠ ABC"],
    ["L \\sim R", "L ∼ R"],
    ["\\lbrace 1, 2 \\rbrace", "{ 1, 2 }"],
  ])("%s → %s", (tex, expected) => {
    expect(texToUnicode(tex)).toBe(expected);
  });

  test("コマンド名は最長で読む（\\leqq を \\leq + q にしない）", () => {
    expect(texToUnicode("a \\leqq b")).toBe("a ≦ b");
  });
});

describe("texToUnicode: 上付き・下付き", () => {
  test.each([
    ["10^5", "10⁵"],
    ["10^9 + 7", "10⁹ + 7"],
    ["10^{18}", "10¹⁸"],
    ["2^{N-1}", "2ᴺ⁻¹"],
    ["a_i", "aᵢ"],
    ["A_1, A_2", "A₁, A₂"],
    ["a_{i+1}", "aᵢ₊₁"],
    ["x_i^2", "xᵢ²"],
    ["0 \\leq a_i \\leq K", "0 ≤ aᵢ ≤ K"],
    ["A_{i,j}", "Aᵢ,ⱼ"],
    ["A_{i, j}", "Aᵢ,ⱼ"],
    ["2^{N - 1}", "2ᴺ⁻¹"],
    ["180^\\circ", "180°"],
    ["180^{\\circ}", "180°"],
    ["A^{\\prime}_1", "A′₁"],
    ["A'", "A′"],
  ])("%s → %s", (tex, expected) => {
    expect(texToUnicode(tex)).toBe(expected);
  });

  test("Unicode に無い文字を含む添字は元の記法のまま残す", () => {
    expect(texToUnicode("a_{q}")).toBe("a_{q}");
    expect(texToUnicode("L_N")).toBe("L_N");
    expect(texToUnicode("A_{N, 1}")).toBe("A_{N, 1}");
    expect(texToUnicode("x^{\\alpha}")).toBe("x^{α}");
  });
});

describe("texToUnicode: 構造", () => {
  test.each([
    ["\\frac{1}{2}", "1/2"],
    ["\\frac{a+b}{2}", "(a+b)/2"],
    ["\\frac{N(N-1)}{2}", "N(N-1)/2"],
    ["\\sqrt{N}", "√N"],
    ["\\sqrt{a+b}", "√(a+b)"],
    ["\\text{Yes}", "Yes"],
    ["\\mathrm{mod}", "mod"],
    ["\\rm{dist}(a, b)", "dist(a, b)"],
    ["\\left( a \\right)", "( a )"],
    ["a\\,b\\ c", "a b c"],
    ["a \\quad b", "a   b"],
  ])("%s → %s", (tex, expected) => {
    expect(texToUnicode(tex)).toBe(expected);
  });

  test("未知のコマンドは元の記法のまま残す", () => {
    expect(texToUnicode("\\foo{a} \\leq b")).toBe("\\foo{a} ≤ b");
  });
});
