import { describe, expect, test } from "bun:test";
import { classifyLine, continuesList, listMarkerLength, plainTextRanges } from "../lib/list.ts";

describe("classifyLine: 直前までの状態と行から、リストの文章かどうかと次の状態を決める", () => {
  test.each([
    ["リスト外で項目の行", false, "* 項目", { textStart: 2, inList: true }],
    ["リスト内で項目の行", true, "  - 入れ子", { textStart: 4, inList: true }],
    ["リスト内の継続行は字下げの後ろから", true, "  継続行", { textStart: 2, inList: true }],
    ["リスト内の字下げなしの継続行", true, "継続行", { textStart: 0, inList: true }],
    ["リスト外の段落", false, "段落", { textStart: null, inList: false }],
    ["リスト内の空行でリストが終わる", true, "", { textStart: null, inList: false }],
    ["リスト内の見出しでリストが終わる", true, "## 見出し", { textStart: null, inList: false }],
  ])("%s", (_name, inListBefore, line, expected) => {
    expect(classifyLine(inListBefore, line)).toEqual(expected);
  });
});

describe("plainTextRanges: 行のうち、インライン記法の外にある地の文の範囲", () => {
  test("記法が無ければ開始位置から行末まで", () => {
    expect(plainTextRanges("* abc", 2)).toEqual([{ start: 2, end: 5 }]);
  });

  test("コード・太字は丸ごと除き、リンクは文字列部分だけ残す", () => {
    const line = "* 項目に `code` と **太字** と [リンク](https://example.com)";
    expect(plainTextRanges(line, 2)).toEqual([
      { start: 2, end: 6 },
      { start: 12, end: 15 },
      { start: 21, end: 24 },
      { start: 25, end: 28 },
    ]);
  });

  test("斜体（* と _）を除く", () => {
    expect(plainTextRanges("* a *b* c _d_ e", 2)).toEqual([
      { start: 2, end: 4 },
      { start: 7, end: 10 },
      { start: 13, end: 15 },
    ]);
  });

  test("タスクのチェックボックスを除く", () => {
    expect(plainTextRanges("* [ ] タスク", 2)).toEqual([{ start: 5, end: 9 }]);
  });

  test("山括弧の自動リンクを除く", () => {
    expect(plainTextRanges("* a <https://x> b", 2)).toEqual([
      { start: 2, end: 4 },
      { start: 15, end: 17 },
    ]);
  });

  test.each([
    ["閉じのないバッククォート", "* a ` b"],
    ["閉じのない強調記号", "* 2 * 3"],
    ["単語の中のアンダースコア", "* a_i と b_j"],
    ["数式", "* $1 \\leq N \\leq 100$"],
    ["閉じのない角括弧", "* a [b c"],
  ])("%s は地の文として扱う", (_name, line) => {
    expect(plainTextRanges(line, 2)).toEqual([{ start: 2, end: line.length }]);
  });

  test("開始位置が行末なら空", () => {
    expect(plainTextRanges("*", 1)).toEqual([]);
  });
});

describe("continuesList: 直前までの行から、次の行がリストの継続行かを判定する", () => {
  test.each([
    ["項目の直後", ["* 項目"]],
    ["継続行の直後", ["* 項目", "  継続行"]],
    ["段落に割り込んだ項目の直後", ["段落", "* 項目"]],
    ["前の塊の後に始まった項目の直後", ["段落", "", "1. 項目"]],
  ])("%s は継続行", (_name, preceding) => {
    expect(continuesList(preceding)).toBe(true);
  });

  test.each([
    ["先頭行", []],
    ["段落の直後", ["段落"]],
    ["項目のあとの空行の直後", ["* 項目", ""]],
    ["空白だけの行の直後", ["* 項目", "   "]],
    ["項目のあとの見出しの直後", ["* 項目", "## 見出し"]],
    ["項目のあとのコードフェンスの直後", ["* 項目", "```"]],
    ["項目のあとの水平線の直後", ["* 項目", "---"]],
  ])("%s は継続行ではない", (_name, preceding) => {
    expect(continuesList(preceding)).toBe(false);
  });
});

describe("listMarkerLength", () => {
  test.each([
    ["* 項目", 2],
    ["- 項目", 2],
    ["+ 項目", 2],
    ["1. 項目", 3],
    ["10) 項目", 4],
    ["  - 入れ子", 4],
    ["*   空白が複数", 4],
    ["*", 1],
  ])("%s の記号部分は %d 文字", (line, length) => {
    expect(listMarkerLength(line)).toBe(length);
  });

  test.each([
    ["記号の直後に空白が無い", "*強調*"],
    ["普通の段落", "段落の文章"],
    ["水平線", "* * *"],
    ["水平線（ハイフン）", "- - -"],
    ["空行", ""],
  ])("%s はリスト項目ではない", (_name, line) => {
    expect(listMarkerLength(line)).toBeNull();
  });
});
