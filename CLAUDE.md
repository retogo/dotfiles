# CLAUDE.md

## このリポジトリについて

Nix flake + home-manager によるdotfiles管理。シェル設定・パッケージを宣言的に管理する。

## 構成

```
flake.nix              # エントリポイント。darwin/linux の homeConfigurations を定義
home/
  common.nix           # 共通パッケージ + zsh 設定（programs.zsh）
  darwin.nix           # macOS 固有（jdk, profileExtra, initContent）
  linux.nix            # Linux 固有（最小限、将来用）
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
- `home.username` / `home.homeDirectory` はリポジトリに固定値を含めず、`flake.nix` で `builtins.getEnv "USER"` / `"HOME"` から取得する。これにより `--impure` 評価が必須になる
