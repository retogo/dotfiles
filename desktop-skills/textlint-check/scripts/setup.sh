#!/usr/bin/env bash
# textlint を書き込み可能なディレクトリへ展開し、そのパスを標準出力に返す。
# 展開済みなら npm ci をスキップする。
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="${TEXTLINT_WORK_DIR:-$HOME/.textlint-check}"

mkdir -p "$work_dir"
cp "$skill_dir/package.json" "$skill_dir/package-lock.json" "$skill_dir/textlintrc.json" "$work_dir/"

if [ ! -x "$work_dir/node_modules/.bin/textlint" ]; then
  (cd "$work_dir" && npm ci --no-audit --no-fund >&2)
fi

echo "$work_dir"
