const TWO_BYTE_MIN = 0x80;
const THREE_BYTE_MIN = 0x800;
const FOUR_BYTE_MIN = 0x10000;

/** 文字列を UTF-8 にしたときのバイト数。 */
export function utf8ByteLength(text: string): number {
  let bytes = 0;
  for (const char of text) {
    const codePoint = char.codePointAt(0) as number;
    if (codePoint < TWO_BYTE_MIN) bytes += 1;
    else if (codePoint < THREE_BYTE_MIN) bytes += 2;
    else if (codePoint < FOUR_BYTE_MIN) bytes += 3;
    else bytes += 4;
  }
  return bytes;
}
