// package.json の直接依存が宣言する bin だけを <prefix>/bin へ張り直す。
// npm ci が作る node_modules/.bin には推移的依存の bin も並ぶため、そこを PATH に
// 通すと codex / semver / yaml のような汎用名が他の管理系のコマンドを shadow する。
import fs from "node:fs";
import path from "node:path";

const prefix = process.argv[2];
const modules = path.join(prefix, "node_modules");
const binDir = path.join(prefix, "bin");

const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const deps = Object.keys(readJson(path.join(prefix, "package.json")).dependencies);

// 消えた依存の bin を残さないため、毎回作り直す。
fs.rmSync(binDir, { recursive: true, force: true });
fs.mkdirSync(binDir, { recursive: true });

for (const dep of deps) {
  const pkgDir = path.join(modules, dep);
  const { bin } = readJson(path.join(pkgDir, "package.json"));
  // textlint のルールプリセットのように bin を持たない依存がある。
  if (!bin) continue;

  const entries = typeof bin === "string" ? { [dep.split("/").pop()]: bin } : bin;
  for (const [name, target] of Object.entries(entries)) {
    fs.symlinkSync(path.relative(binDir, path.join(pkgDir, target)), path.join(binDir, name));
  }
}
