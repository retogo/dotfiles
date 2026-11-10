// Markdown のリスト項目の文章を本文の色で表示する。
// Fresh はリスト項目を行ごと syntax.operator の色で塗るため、演算子に色を付けるテーマでは
// リストの文章までその色になる。記号（`*` や `1.`）とインライン記法の色は変えない。

import { classifyLine, continuesList, plainTextRanges } from "./lib/list.ts";
import { utf8ByteLength } from "./lib/utf8.ts";

const editor = getEditor();

const NAMESPACE = "md-list-text";
const TEXT_STYLE = { fg: "editor.fg" };
const MARKDOWN_EXTENSIONS = [".md", ".markdown"];

/** バッチの先頭行がリストの途中かを調べるために、手前から読むバイト数。 */
const LOOKBEHIND_BYTES = 4096;

function isMarkdown(bufferId: number): boolean {
  const path = editor.getBufferPath(bufferId);
  return MARKDOWN_EXTENSIONS.some((extension) => path.endsWith(extension));
}

/** `byteStart` から始まる行の直前まで、リストが続いているか。 */
async function inListBefore(bufferId: number, byteStart: number): Promise<boolean> {
  if (byteStart === 0) return false;
  const text = await editor.getBufferText(bufferId, Math.max(0, byteStart - LOOKBEHIND_BYTES), byteStart);
  const preceding = text.split("\n");
  // 直前の行の改行より後ろ（空文字列）を除く
  preceding.pop();
  return continuesList(preceding);
}

editor.on("lines_changed", async (data) => {
  if (data.lines.length === 0 || !isMarkdown(data.buffer_id)) return;
  try {
    let inList = false;
    let previousLineNumber: number | null = null;
    for (const line of data.lines) {
      if (previousLineNumber === null || line.line_number !== previousLineNumber + 1) {
        inList = await inListBefore(data.buffer_id, line.byte_start);
      }
      previousLineNumber = line.line_number;

      editor.clearOverlaysInRangeForNamespace(data.buffer_id, NAMESPACE, line.byte_start, line.byte_end);
      // コードブロックの行はリストの文章として扱わない
      if (line.region !== undefined) {
        inList = false;
        continue;
      }
      const lineClass = classifyLine(inList, line.content);
      inList = lineClass.inList;
      if (lineClass.textStart === null) continue;

      for (const range of plainTextRanges(line.content, lineClass.textStart)) {
        const start = line.byte_start + utf8ByteLength(line.content.slice(0, range.start));
        const end = start + utf8ByteLength(line.content.slice(range.start, range.end));
        editor.addOverlay(data.buffer_id, NAMESPACE, start, end, TEXT_STYLE);
      }
    }
  } catch (error) {
    // 捕まえない例外はプラグイン実行環境ごと止めてしまう
    editor.debug(`markdown-list-text: ${error}`);
  }
});
