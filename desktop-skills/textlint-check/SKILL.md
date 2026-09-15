---
name: textlint-check
description: >
  Markdown や日本語の文章を textlint で校正し、技術文書としての品質を検証・修正する。
  「文章をチェック」「textlint かけて」「日本語チェック」「文章校正」「校正して」
  といったリクエスト、または添付された .md ファイルの品質確認を求められたときに使う。
  preset-ja-technical-writing / preset-ai-writing / preset-ai-words-ja /
  preset-ja-spacing の 4 プリセットを適用する。
---

# textlint-check

日本語の Markdown に textlint を実行し、指摘の報告と修正を行う。

## 適用プリセット

| プリセット                       | 対象                                    |
| -------------------------------- | --------------------------------------- |
| `preset-ja-technical-writing`    | 一文の長さ、読点の数、二重否定など      |
| `@textlint-ja/preset-ai-writing` | AI が書きがちな冗長表現・定型句         |
| `preset-ai-words-ja`             | AI 特有の語彙（「まさに」「革新的」等） |
| `preset-ja-spacing`              | 全角・半角間のスペース、括弧前後の空白  |

## セットアップ

textlint は実行環境に入っていないため、最初に一度だけ展開する。

```bash
TEXTLINT_DIR="$(bash "$SKILL_DIR/scripts/setup.sh")"
```

`$SKILL_DIR` はこの SKILL.md が置かれているディレクトリ。
初回は `npm ci` が走るため 1 分程度かかる。2 回目以降は即座に返る。
以降のコマンドはすべて `$TEXTLINT_DIR` 配下のバイナリと設定を使う。

## ワークフロー

### 1. 対象の特定

- 添付ファイルは `/mnt/user-data/uploads/` に置かれる
- 会話中に貼られたテキストは `/tmp/` に `.md` として書き出してから渡す

### 2. 実行

```bash
"$TEXTLINT_DIR/node_modules/.bin/textlint" -c "$TEXTLINT_DIR/textlintrc.json" <対象ファイル>
```

指摘が 1 件でもあると終了コードは 1 になる。

### 3. 報告

- ルール別の件数を表にまとめる
- 自動修正できる指摘（`✓` 付き）とできない指摘を分けて示す
- 手動修正が必要なものは該当箇所の原文を添えて提示する

### 4. 修正

1. 元ファイルを `/mnt/user-data/outputs/` へコピーし、以降はコピーを編集する
2. `--fix` で自動修正できるものを処理する

   ```bash
   "$TEXTLINT_DIR/node_modules/.bin/textlint" -c "$TEXTLINT_DIR/textlintrc.json" --fix <対象ファイル>
   ```

3. 残った指摘を本文を読んで修正する
4. 再度 textlint を実行し、指摘が解消したことを確認する
5. 修正後のファイルをユーザーに渡す

## 注意事項

- `--fix` は文章全体に一括で効く。日本語の文書では全角・半角間スペースの指摘が大量に出るが、
  英単語の前後にスペースを意図的に入れているケースがあるため、`--fix` を当てる前に
  どのルールが自動修正されるかをユーザーに確認する
- コードブロック・テーブル内の指摘は誤検出のことがある。原文を確認してから直す
- ルールを絞りたい場合は `$TEXTLINT_DIR/textlintrc.json` を編集してから実行する
