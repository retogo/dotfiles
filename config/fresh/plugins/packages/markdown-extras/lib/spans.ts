export interface MathSpan {
  /** 開きの `$` の位置（UTF-16 単位） */
  start: number;
  /** 閉じの `$` の直後の位置（UTF-16 単位） */
  end: number;
  /** `$` を除いた中身 */
  tex: string;
}

const WHITESPACE = /\s/;
const DIGIT = /[0-9]/;

/** `start` から続く同じ文字 `char` の個数。 */
function runLength(line: string, start: number, char: string): number {
  let end = start;
  while (line[end] === char) end++;
  return end - start;
}

/**
 * `open` にある長さ `width` の `$` 区切りに対応する閉じ区切りの位置。無ければ -1。
 * 閉じの直前が空白のもの、`$` 1 個で直後が数字のもの（金額）は閉じと見なさない。
 */
function closingDelimiter(line: string, open: number, width: number): number {
  for (let i = open + width; i < line.length; i++) {
    if (line[i] === "\\") { i++; continue; }
    if (line[i] !== "$") continue;
    if (runLength(line, i, "$") < width) continue;
    if (i === open + width) return -1;
    if (WHITESPACE.test(line[i - 1])) continue;
    if (width === 1 && DIGIT.test(line[i + 1] ?? "")) continue;
    return i;
  }
  return -1;
}

/** 行の中のインライン数式（`$...$` と 1 行に収まる `$$...$$`）を返す。 */
export function findMathSpans(line: string): MathSpan[] {
  const spans: MathSpan[] = [];
  let i = 0;
  while (i < line.length) {
    const char = line[i];
    if (char === "\\") {
      i += 2;
    } else if (char === "`") {
      const fence = "`".repeat(runLength(line, i, "`"));
      const close = line.indexOf(fence, i + fence.length);
      i = close === -1 ? i + fence.length : close + fence.length;
    } else if (char === "$") {
      const width = Math.min(runLength(line, i, "$"), 2);
      const first = line[i + width];
      const close = first === undefined || WHITESPACE.test(first) ? -1 : closingDelimiter(line, i, width);
      if (close === -1) {
        i += width;
      } else {
        spans.push({ start: i, end: close + width, tex: line.slice(i + width, close) });
        i = close + width;
      }
    } else {
      i++;
    }
  }
  return spans;
}