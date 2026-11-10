const LIST_MARKER = /^\s*(?:[*+-]|\d{1,9}[.)])(?:\s+|$)/;
const THEMATIC_BREAK = /^\s*([*_-])(?:\s*\1){2,}\s*$/;

export interface Range {
  /** 開始位置（UTF-16 単位） */
  start: number;
  /** 終了位置の直後（UTF-16 単位） */
  end: number;
}

const WHITESPACE = /\s/;
const WORD_CHARACTER = /[\p{L}\p{N}]/u;
const AUTOLINK = /^<[^\s<>]+>/;

/** `start` から続く同じ文字 `char` の個数。 */
function runLength(line: string, start: number, char: string): number {
  let end = start;
  while (line[end] === char) end++;
  return end - start;
}

/**
 * `open` にある強調記号（`*` か `_` の連続 `delimiter`）に対応する閉じ記号の位置。無ければ -1。
 * `_` は単語の途中では強調にならない。
 */
function closingEmphasis(line: string, open: number, delimiter: string): number {
  const char = delimiter[0];
  const afterOpen = line[open + delimiter.length];
  if (afterOpen === undefined || WHITESPACE.test(afterOpen)) return -1;
  if (char === "_" && open > 0 && WORD_CHARACTER.test(line[open - 1])) return -1;

  for (let i = open + delimiter.length + 1; i < line.length; i++) {
    if (line[i] === "\\") { i++; continue; }
    if (!line.startsWith(delimiter, i)) continue;
    if (WHITESPACE.test(line[i - 1])) continue;
    const afterClose = line[i + delimiter.length];
    if (char === "_" && afterClose !== undefined && WORD_CHARACTER.test(afterClose)) continue;
    return i;
  }
  return -1;
}

/** `from` 以降にあるインライン記法（コード、強調、リンクの記号と URL など）の範囲。 */
function inlineSyntaxRanges(line: string, from: number): Range[] {
  const ranges: Range[] = [];
  let i = from;
  while (i < line.length) {
    const char = line[i];
    if (char === "\\") {
      i += 2;
    } else if (char === "`") {
      const fence = "`".repeat(runLength(line, i, "`"));
      const close = line.indexOf(fence, i + fence.length);
      if (close !== -1) ranges.push({ start: i, end: close + fence.length });
      i = close === -1 ? i + fence.length : close + fence.length;
    } else if (char === "*" || char === "_") {
      const delimiter = char.repeat(runLength(line, i, char));
      const close = closingEmphasis(line, i, delimiter);
      if (close !== -1) ranges.push({ start: i, end: close + delimiter.length });
      i = close === -1 ? i + delimiter.length : close + delimiter.length;
    } else if (char === "[" || (char === "!" && line[i + 1] === "[")) {
      const open = char === "!" ? i + 1 : i;
      const close = line.indexOf("]", open + 1);
      const urlEnd = close !== -1 && line[close + 1] === "(" ? line.indexOf(")", close + 2) : -1;
      if (close === -1) {
        i = open + 1;
      } else if (urlEnd === -1) {
        ranges.push({ start: i, end: close + 1 });
        i = close + 1;
      } else {
        ranges.push({ start: i, end: open + 1 }, { start: close, end: urlEnd + 1 });
        i = urlEnd + 1;
      }
    } else if (char === "<") {
      const autolink = AUTOLINK.exec(line.slice(i));
      if (autolink) ranges.push({ start: i, end: i + autolink[0].length });
      i += autolink ? autolink[0].length : 1;
    } else {
      i++;
    }
  }
  return ranges;
}

/** `from` から行末までのうち、インライン記法の外にある地の文の範囲。 */
export function plainTextRanges(line: string, from: number): Range[] {
  const plain: Range[] = [];
  let start = from;
  for (const syntax of inlineSyntaxRanges(line, from)) {
    if (syntax.start > start) plain.push({ start, end: syntax.start });
    start = syntax.end;
  }
  if (line.length > start) plain.push({ start, end: line.length });
  return plain;
}

const BLANK = /^\s*$/;
const HEADING = /^\s{0,3}#{1,6}(?:\s|$)/;
const CODE_FENCE = /^\s*(?:```|~~~)/;

/** リストを終わらせる行（空行、見出し、コードフェンス、水平線）か。 */
function endsList(line: string): boolean {
  return BLANK.test(line) || HEADING.test(line) || CODE_FENCE.test(line) || THEMATIC_BREAK.test(line);
}

/**
 * `preceding`（対象行より前の行。末尾が直前の行）に続く行が、リスト項目の継続行になるか。
 * 対象行自身が項目の行かどうかは見ない。
 */
export function continuesList(preceding: string[]): boolean {
  for (let i = preceding.length - 1; i >= 0; i--) {
    if (endsList(preceding[i])) return false;
    if (listMarkerLength(preceding[i]) !== null) return true;
  }
  return false;
}

export interface LineClass {
  /** リストの文章が始まる位置（UTF-16 単位）。リストの行でなければ `null` */
  textStart: number | null;
  /** この行の後もリストが続いているか */
  inList: boolean;
}

const LEADING_WHITESPACE = /^\s*/;

/** 直前の行までリストが続いていたか（`inListBefore`）と行の内容から、行の種類と次の状態を決める。 */
export function classifyLine(inListBefore: boolean, line: string): LineClass {
  if (endsList(line)) return { textStart: null, inList: false };
  const markerLength = listMarkerLength(line);
  if (markerLength !== null) return { textStart: markerLength, inList: true };
  if (!inListBefore) return { textStart: null, inList: false };
  return { textStart: (LEADING_WHITESPACE.exec(line) as RegExpExecArray)[0].length, inList: true };
}

/** リスト項目の行なら、行頭の字下げ・記号・後続の空白を合わせた長さ。項目でなければ `null`。 */
export function listMarkerLength(line: string): number | null {
  if (THEMATIC_BREAK.test(line)) return null;
  const marker = LIST_MARKER.exec(line);
  return marker ? marker[0].length : null;
}
