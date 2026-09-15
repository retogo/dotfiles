#!/usr/bin/env bash
# claude.ai / Claude Desktop の Settings > Capabilities > Skills にアップロードする
# zip を dist/ に生成する。
#
#   ./desktop-skills/build.sh textlint-check
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
skill="$1"

mkdir -p dist
rm -f "dist/$skill.zip"
zip -qr "dist/$skill.zip" "$skill" -x '*/.DS_Store'

echo "$PWD/dist/$skill.zip"
