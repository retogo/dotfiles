// Markdown の整形表示（compose）で、インライン数式 `$...$` を Unicode の数式表記に
// 置き換えて見せる。カーソルが同じ行にある間は元の TeX 記法を表示する。

import { findMathSpans, utf8ByteLength } from "./lib/spans.ts";
import { texToUnicode } from "./lib/tex.ts";

const editor = getEditor();

const NAMESPACE = "md-math";

editor.on("lines_changed", (data) => {
  if (!data.is_composing_in_any_split) return;
  for (const line of data.lines) {
    editor.clearConcealsInRangeForNamespace(data.buffer_id, NAMESPACE, line.byte_start, line.byte_end);
    // コードブロックの中は数式として扱わない
    if (line.region !== undefined) continue;
    for (const span of findMathSpans(line.content)) {
      const start = line.byte_start + utf8ByteLength(line.content.slice(0, span.start));
      const end = start + utf8ByteLength(line.content.slice(span.start, span.end));
      editor.addConceal(
        data.buffer_id, NAMESPACE, start, end, texToUnicode(span.tex),
        "unless-cursor-in", line.byte_start, line.byte_end + 1, true,
      );
    }
  }
});
