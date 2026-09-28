# dotfiles

Nix flake + home-manager による開発環境管理。言語ランタイムなど一部のツールは mise で管理する。

## セットアップ

```sh
git clone https://github.com/retogo/dotfiles.git
cd dotfiles
./install.sh
```

`install.sh` は次の順に実行する。

1. Nix が無ければインストールする
2. OS を判定して `darwin` / `linux` のいずれかの configuration を home-manager で適用する
3. `mise install` で mise 管理のツールを取得する

`home.username` と `home.homeDirectory` は flake 評価時に環境変数 `$USER` / `$HOME` から取得するため、`--impure` 付きで実行される（`install.sh` 内で指定済み）。

直接コマンドで実行する場合:

```sh
home-manager switch --flake .#darwin --impure   # macOS
home-manager switch --flake .#linux  --impure   # Linux
mise install
```

## 設定の変更

1. `home/` / `shell/` / `config/` / `npm/` のファイルを編集
2. `npm/package.json` を編集した場合は `npm install --package-lock-only --prefix npm` で `package-lock.json` を再生成する
3. 新規ファイルを追加した場合は `git add` する（flake は未追跡ファイルを無視する）
4. `./install.sh` で再適用

## 構成

| パス                      | 内容                                                 |
| ------------------------- | ---------------------------------------------------- |
| `flake.nix`               | エントリポイント。darwin / linux の出し分け          |
| `home/common.nix`         | 共通パッケージ・zsh 設定・設定ファイルの配置         |
| `home/darwin.nix`         | macOS 固有設定                                       |
| `home/linux.nix`          | Linux 固有設定                                       |
| `shell/common.sh`         | 共通シェル関数                                       |
| `shell/darwin.sh`         | macOS 固有のシェル設定                               |
| `shell/darwin-profile.sh` | macOS のログイン時設定                               |
| `config/`                 | `~` / `~/.config` に配る設定ファイルの実体           |
| `config/mise/config.toml` | mise で管理するツールの版                            |
| `npm/`                    | `~/.npm-global` に展開する npm パッケージと lockfile |

## パッケージの追加

パッケージの種類によって宣言先が `config/mise/config.toml` / `home/common.nix` / `npm/package.json` に分かれる。判定規則は [CLAUDE.md](CLAUDE.md) の「パッケージの管理先」に従う。

## devcontainer

VS Code の設定に以下を追加すると、コンテナ起動時に自動適用される:

```json
{
  "dotfiles.repository": "retogo/dotfiles",
  "dotfiles.installCommand": "./install.sh"
}
```
