# CLAUDE.md

## このリポジトリについて

Nix flake + home-manager によるdotfiles管理。シェル設定・パッケージを宣言的に管理する。

## 構成

```
flake.nix              # エントリポイント。darwin/linux の homeConfigurations を定義
home/
  common.nix           # 共通パッケージ + zsh 設定（programs.zsh）
  darwin.nix           # macOS 固有（profileExtra, initContent, ghostty）
  linux.nix            # Linux 固有（最小限、将来用）
config/
  mise/config.toml     # mise が管理する言語ランタイムの版（node / bun / java）
shell/
  common.sh            # 共通シェル関数（cdp, メモ関数群）
  darwin.sh            # macOS 固有の initContent（Docker, uuidgen）
  darwin-profile.sh    # macOS 固有の profileExtra（Homebrew, Obsidian PATH）
npm/
  package.json         # nixpkgs に無い npm パッケージの宣言。switch 時に ~/.npm-global へ展開
```

## ビルド・適用

`install.sh` 経由で実行する（OS 判定 + `--impure` を自動付与）:

```sh
./install.sh
```

直接実行する場合:

```sh
home-manager switch --flake .#darwin --impure   # macOS
home-manager switch --flake .#linux  --impure   # Linux
```

新しいファイルを追加したら `git add` してからビルドすること（flake は未追跡ファイルを無視する）。

## 設計方針

- シェルは zsh に統一（bash 設定は不要）
- `.zshrc` / `.zshenv` / `.zprofile` は全て home-manager が Nix store への symlink として管理。手動 symlink は使わない
- シェル設定は `programs.zsh` の各オプションで管理し、実際のシェルスクリプトは `shell/` ディレクトリに分離
- 環境固有の設定は `home/{darwin,linux}.nix` + `shell/{darwin,darwin-profile}.sh` で分離
- `initExtra` は非推奨。`initContent` を使うこと（`lib.mkBefore` / `lib.mkAfter` で順序制御）
- unfree パッケージは `flake.nix` の `allowUnfreePredicate` で明示的に許可する
- nixpkgs に無い npm パッケージは `npm/package.json` に追記（バージョン固定）。`home-manager switch` 時に `~/.npm-global` へ `npm install` され、`~/.npm-global/node_modules/.bin` が PATH に通る

### Nix と mise の境界線

パッケージをどちらで入れるかは次の規則で機械的に決める。裁量で判断しない。

- **原則: nixpkgs にあるものは Nix、無いものは mise**。判定は `nix eval` で確認できる
- **例外: node / bun / java は mise**（`config/mise/config.toml`）。言語自身がバージョン切り替え機構を持たず、プロジェクト単位で切り替える必要があるため
  - go（`GOTOOLCHAIN`）・rust（`rustup` + `rust-toolchain.toml`）・python（`uv` が `requires-python` を解決）は切り替え機構を言語側が持つので Nix に据え置く
- mise 自体は nixpkgs から入れる（`programs.mise`）。並立する 2 系統ではなく、Nix が mise を導入する層構造にする
- 迷ったら `which <cmd>` で判別できる。`/nix/store/...` なら Nix、`~/.local/share/mise/...` なら mise
- `programs.mise.package` は既定が `null` で、null だとシェル統合が入らないため必ず明示する
- `~/.config/mise/config.toml` は store への symlink（読み取り専用）なので `mise use -g` は使えない。`config/mise/config.toml` を編集して `./install.sh` し直す
- `home.username` / `home.homeDirectory` はリポジトリに固定値を含めず、`flake.nix` で `builtins.getEnv "USER"` / `"HOME"` から取得する。これにより `--impure` 評価が必須になる
