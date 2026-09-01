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
  package.json         # npm パッケージの宣言。switch 時に ~/.npm-global へ npm ci で展開
  package-lock.json    # 上記の推移的依存の固定。npm install で再生成する
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
- `home.username` / `home.homeDirectory` はリポジトリに固定値を含めず、`flake.nix` で `builtins.getEnv "USER"` / `"HOME"` から取得する。これにより `--impure` 評価が必須になる

## パッケージの管理先

追加するパッケージをどこで宣言するかは、上から順に機械的に判定する。裁量で判断しない。

| # | 条件                         | 管理先                                                 |
| - | ---------------------------- | ------------------------------------------------------ |
| 0 | 自己更新するエージェント CLI | 管理対象外（公式インストーラで `~/.local/bin` へ）     |
| 1 | node / bun / java            | `config/mise/config.toml`                              |
| 2 | nixpkgs にある               | `home/common.nix` の `home.packages`                   |
| 3 | npm パッケージ               | `npm/package.json`                                     |
| 4 | 上記以外                     | `config/mise/config.toml`（`http` / `github` backend） |

- 0 は Claude Code と codex。どちらも self-update 機構を自身に持ち、更新のたびに宣言と実体がずれるため、宣言的管理から外して各公式インストーラに任せる
  - codex は `curl -fsSL https://chatgpt.com/codex/install.sh | sh` で入れる。`npm install -g` は使わない（npm の prefix が mise の node install ディレクトリを指すため、mise 管理下に紛れ込む）
  - takt の推移的依存として `~/.npm-global/node_modules/.bin/codex` も入るが、PATH は `~/.local/bin` が先なので公式インストーラ版が優先される
- 1 が例外なのは、これらの言語自身がバージョン切り替え機構を持たないため。go は `GOTOOLCHAIN`、rust は `rustup` + `rust-toolchain.toml`、python は `uv` が `requires-python` を解決するので、Nix に置く
- 2 の判定は `nix eval` で確認する
- 3 は `home-manager switch` 時に `~/.npm-global` へ `npm ci` で展開され、`~/.npm-global/node_modules/.bin` が PATH に通る。単体 CLI も、textlint のようにプリセットと `node_modules` を共有する必要があるツールチェーンも、ここにまとめる
- `npm/package.json` を編集したら `npm install --package-lock-only --prefix npm` で `package-lock.json` を再生成して両方 commit する
- バージョンはいずれの管理先でも固定する。npm パッケージは min release age 7 日を満たす版のみ採用する
- 自前 derivation は持たない。nixpkgs に無いものは mise の backend で解決する

### mise

- mise 自体は nixpkgs から入れる（`programs.mise`）。Nix が mise を導入する層構造にし、2 系統を並立させない
- `programs.mise.package` を明示する。既定は `null` で、`null` のままだとシェル統合が生成されない
- `programs.mise.globalConfig` は空のままにする。設定すると module が `~/.config/mise/config.toml` を生成し、`xdg.configFile` の同名エントリと衝突する
- `~/.config/mise/config.toml` は store への symlink なので `mise use -g` は使えない。`config/mise/config.toml` を編集して `./install.sh` し直す
- プロジェクト単位の上書きは各リポジトリの `mise.toml` で行う
- `mise activate` は対話シェルにしか効かない。非対話プロセスから解決させるため `~/.local/share/mise/shims` を `home.sessionPath` に入れる
