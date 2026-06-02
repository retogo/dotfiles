---
name: bumping-vendored-derivation
description: nixpkgs に無いため `home/common.nix` の `let` ブロックで自前 derivation 化したパッケージ（例: ntn）のバージョン追従を行う。「ntn 更新」「notion-cli 更新」「自前 derivation を bump」「derivation のバージョンを上げて」などのリクエストで発動する。
allowed-tools: Bash, Read, Edit, Glob, Grep
---

# 自前 derivation の追従

`home/common.nix` の先頭 `let` ブロックには、nixpkgs に存在しないため自前で `pkgs.stdenv.mkDerivation` で包んだバイナリ配布パッケージが束ねられている。新バージョンが出たら version とプラットフォーム別の sha256 を差し替える。

## 前提

- 対象は `home/common.nix` の `let` 内で定義されている derivation のみ。`home.packages` 内の素の `pkgs.<name>` (nixpkgs パッケージ) は対象外
- 当リポジトリは darwin / linux 両対応で書かれている。サポートプラットフォームは各 derivation の `sources` 属性で宣言済み
- 動作確認は `./install.sh` 経由で `home-manager switch` する。これが各 derivation の fetch とビルドを行う

## 手順

### 1. 対象 derivation を特定する

`home/common.nix` の `let ... in` ブロックを Read し、ユーザーが指定したパッケージ（`ntn` など）の derivation を探す。`version = "..."` と `sources = { ... }` の構造を持つ。

複数指定された場合 / "全部" 指定された場合は、`let` 内の全 derivation を対象にする。

### 2. 最新バージョンを確認する

derivation 内のコメント / `meta.homepage` / 周辺コメントから配布元 URL のパターンを読み取り、最新版を確認する。

例: ntn の場合

```sh
curl -fsSL https://ntn.dev/latest.txt
```

配布元の規約が読み取れない場合はユーザーに最新バージョンを聞く。憶測でバージョンを当てない。

ユーザーから明示的にバージョン指定 (例: 「v0.15.0 に上げて」) があればそれを採用し、最新確認はスキップしてよい。

### 3. 新しい sha256 を 4 プラットフォーム分取得する

各 derivation は `sources` 属性に `aarch64-darwin` / `x86_64-darwin` / `x86_64-linux` / `aarch64-linux` の 4 つを持つ。それぞれの `target` 値をそのまま URL に差し込み、`.sha256` を取得する。

```sh
VERSION=v0.14.1   # 新バージョン
for target in aarch64-apple-darwin x86_64-apple-darwin x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
  echo "=== ${target} ==="
  curl -fsSL "https://ntn.dev/releases/${VERSION}/ntn-${target}.tar.gz.sha256"
done
```

URL パターンが derivation のコメント / `src.url` から読み取れない場合は、`src = pkgs.fetchurl { url = ...; }` の `url` 式を見て手で組み立てる。

`.sha256` ファイルが配布されていない upstream の場合は `nix-prefetch-url <archive_url>` で代用する。

### 4. version と sha256 を差し替える

`home/common.nix` を Edit する。一括置換ではなく、対象 derivation のブロック内のみ差し替える（他 derivation の sha256 と衝突しないようにする）。

差し替える箇所:

- `version = "X.Y.Z";`
- `sources.<system>.sha256 = "...";`（4 つ全て）

`target` 値は通常変わらない。upstream がリリース成果物名を変更した場合のみ書き換える。

### 5. ビルド & 動作確認

```sh
./install.sh
```

ビルドが通ったら、対象パッケージのバイナリを起動して新バージョンが入ったか確認する。バイナリ名と `--version` フラグは derivation により異なるので、`installPhase` の `install -Dm0755 <src> $out/bin/<name>` から実行ファイル名を拾う。

```sh
which <bin>
<bin> --version
```

`--version` が無いツールの場合は `--help` の出力やバージョン文字列が含まれる別フラグで確認する。

## 注意事項

- **sha256 のハッシュは upstream のものをそのまま使う**。Nix が期待する形式（base32 / SRI）と異なっていても `fetchurl` は hex も受け付けるので、`.sha256` ファイルの hex 値をコピーすればよい。形式変換を勝手に挟まない
- **`./install.sh` の失敗時は sha256 ミスマッチを最初に疑う**。Nix のエラーメッセージに `hash mismatch` / `got: sha256-...` が出ていたら、`got` の値で差し替える（upstream の `.sha256` が壊れている場合の最終手段）
- **複数 derivation をまとめて更新するときは 1 commit にしない**。derivation ごとに動作確認できる粒度で分け、コミット粒度はユーザーに確認する
- **`home/common.nix` の `let` ブロック以外には触らない**。`home.packages` リストには derivation を追加・削除しない（バージョン bump のスコープを超える）
