const SYMBOLS: Record<string, string> = {
  leq: "≤", le: "≤", leqq: "≦", geq: "≥", ge: "≥", geqq: "≧",
  neq: "≠", ne: "≠", lt: "<", gt: ">", approx: "≈", equiv: "≡",
  ldots: "…", dots: "…", cdots: "⋯", vdots: "⋮",
  times: "×", cdot: "·", div: "÷", pm: "±",
  in: "∈", notin: "∉", subset: "⊂", subseteq: "⊆", cup: "∪", cap: "∩", emptyset: "∅",
  to: "→", rightarrow: "→", leftarrow: "←", Rightarrow: "⇒", Leftrightarrow: "⇔",
  lfloor: "⌊", rfloor: "⌋", lceil: "⌈", rceil: "⌉", lvert: "|", rvert: "|", lbrace: "{", rbrace: "}",
  infty: "∞", sum: "∑", prod: "∏", forall: "∀", exists: "∃", angle: "∠", sim: "∼", circ: "∘", prime: "′",
  land: "∧", lor: "∨", lnot: "¬", oplus: "⊕",
  bmod: "mod", mod: "mod", max: "max", min: "min", gcd: "gcd", log: "log",
  alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", theta: "θ",
  lambda: "λ", mu: "μ", pi: "π", sigma: "σ", phi: "φ", omega: "ω",
  Delta: "Δ", Sigma: "Σ", Omega: "Ω",
};

const SUPERSCRIPTS: Record<string, string> = {
  "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
  "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", " ": "", ",": ",", "∘": "°", "′": "′",
  a: "ᵃ", b: "ᵇ", c: "ᶜ", d: "ᵈ", e: "ᵉ", f: "ᶠ", g: "ᵍ", h: "ʰ", i: "ⁱ", j: "ʲ", k: "ᵏ", l: "ˡ", m: "ᵐ",
  n: "ⁿ", o: "ᵒ", p: "ᵖ", r: "ʳ", s: "ˢ", t: "ᵗ", u: "ᵘ", v: "ᵛ", w: "ʷ", x: "ˣ", y: "ʸ", z: "ᶻ",
  A: "ᴬ", B: "ᴮ", D: "ᴰ", E: "ᴱ", G: "ᴳ", H: "ᴴ", I: "ᴵ", J: "ᴶ", K: "ᴷ", L: "ᴸ", M: "ᴹ", N: "ᴺ",
  O: "ᴼ", P: "ᴾ", R: "ᴿ", T: "ᵀ", U: "ᵁ", V: "ⱽ", W: "ᵂ",
};

const SUBSCRIPTS: Record<string, string> = {
  "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
  "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎", " ": "", ",": ",",
  a: "ₐ", e: "ₑ", h: "ₕ", i: "ᵢ", j: "ⱼ", k: "ₖ", l: "ₗ", m: "ₘ", n: "ₙ", o: "ₒ", p: "ₚ", r: "ᵣ",
  s: "ₛ", t: "ₜ", u: "ᵤ", v: "ᵥ", x: "ₓ",
};

const SCRIPT_TABLES: Record<string, Record<string, string>> = { "^": SUPERSCRIPTS, "_": SUBSCRIPTS };

/** 引数の中身だけを残すコマンド（書体・テキスト指定）。 */
const TRANSPARENT_COMMANDS = new Set([
  "text", "textrm", "textbf", "textit", "mathrm", "mathbf", "mathit", "mathtt", "operatorname",
]);

/** 何も出力しないコマンド（括弧の大きさ指定、後続に効く書体切り替えなど）。 */
const SILENT_COMMANDS = new Set(["left", "right", "displaystyle", "limits", "nolimits", "rm", "bf", "it"]);

const PRIME = "′";

const SPACE_COMMANDS: Record<string, string> = { quad: " ", qquad: "  " };

/** `\,` のような記号 1 文字のコマンド。ここに無い記号はその文字自身になる（`\{` → `{`）。 */
const PUNCTUATION_COMMANDS: Record<string, string> = { ",": " ", ";": " ", ":": " ", " ": " ", "!": "" };

const COMMAND_NAME = /^[A-Za-z]+/;

interface Argument {
  /** 引数を変換した結果 */
  text: string;
  /** 引数の直後の位置 */
  next: number;
  /** `{...}` で囲まれていたか */
  braced: boolean;
}

/** `open` にある `{` に対応する `}` の位置。 */
function closingBrace(tex: string, open: number): number {
  let depth = 0;
  for (let i = open; i < tex.length; i++) {
    if (tex[i] === "\\") { i++; continue; }
    if (tex[i] === "{") depth++;
    if (tex[i] === "}" && --depth === 0) return i;
  }
  return tex.length;
}

/** `start` から 1 引数（`{...}`、`\command`、または 1 文字）を読む。 */
function readArgument(tex: string, start: number): Argument {
  if (tex[start] === "{") {
    const close = closingBrace(tex, start);
    return { text: texToUnicode(tex.slice(start + 1, close)), next: close + 1, braced: true };
  }
  if (tex[start] === "\\") {
    const name = COMMAND_NAME.exec(tex.slice(start + 1));
    const end = start + 1 + (name ? name[0].length : 1);
    return { text: texToUnicode(tex.slice(start, end)), next: end, braced: false };
  }
  return { text: tex.slice(start, start + 1), next: start + 1, braced: false };
}

/** 全文字が `table` にあれば添字に変換し、1 文字でも無ければ `null`。 */
function toScript(text: string, table: Record<string, string>): string | null {
  let script = "";
  for (const char of text) {
    const mapped = table[char];
    if (mapped === undefined) return null;
    script += mapped;
  }
  return script;
}

/** 括弧の外に演算子や空白があり、分数や根号の中で括弧が要る式か。 */
function needsParentheses(text: string): boolean {
  let depth = 0;
  for (const char of text) {
    if (char === "(") depth++;
    else if (char === ")") depth--;
    else if (depth === 0 && (char === "+" || char === "-" || char === " ")) return true;
  }
  return false;
}

function parenthesize(text: string): string {
  return needsParentheses(text) ? `(${text})` : text;
}

interface Converted {
  text: string;
  /** コマンドとその引数の直後の位置 */
  next: number;
}

/** `start` にある `\` から始まるコマンドを変換する。 */
function convertCommand(tex: string, start: number): Converted {
  const match = COMMAND_NAME.exec(tex.slice(start + 1));
  if (!match) {
    const punctuation = tex[start + 1] ?? "";
    return { text: PUNCTUATION_COMMANDS[punctuation] ?? punctuation, next: start + 2 };
  }
  const name = match[0];
  const afterName = start + 1 + name.length;

  if (name === "frac") {
    const numerator = readArgument(tex, afterName);
    const denominator = readArgument(tex, numerator.next);
    return { text: `${parenthesize(numerator.text)}/${parenthesize(denominator.text)}`, next: denominator.next };
  }
  if (name === "sqrt") {
    const radicand = readArgument(tex, afterName);
    return { text: `√${parenthesize(radicand.text)}`, next: radicand.next };
  }
  if (TRANSPARENT_COMMANDS.has(name)) {
    const content = readArgument(tex, afterName);
    return { text: content.text, next: content.next };
  }
  if (SILENT_COMMANDS.has(name)) return { text: "", next: afterName };
  if (name in SPACE_COMMANDS) return { text: SPACE_COMMANDS[name], next: afterName };
  if (name in SYMBOLS) return { text: SYMBOLS[name], next: afterName };

  let end = afterName;
  while (tex[end] === "{") end = closingBrace(tex, end) + 1;
  return { text: tex.slice(start, end), next: end };
}

export function texToUnicode(tex: string): string {
  let out = "";
  let i = 0;
  while (i < tex.length) {
    const char = tex[i];
    if (char === "\\") {
      const command = convertCommand(tex, i);
      out += command.text;
      i = command.next;
    } else if (char === "^" || char === "_") {
      const argument = readArgument(tex, i + 1);
      const script = toScript(argument.text, SCRIPT_TABLES[char]);
      out += script ?? (argument.braced ? `${char}{${argument.text}}` : char + argument.text);
      i = argument.next;
    } else if (char === "{") {
      const argument = readArgument(tex, i);
      out += argument.text;
      i = argument.next;
    } else if (char === "'") {
      out += PRIME;
      i++;
    } else {
      out += char;
      i++;
    }
  }
  return out;
}
