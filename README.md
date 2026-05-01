# dotfiles

Nix flake + home-manager による開発環境管理。

## セットアップ

### 1. Nix のインストール

```sh
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
```

### 2. home-manager の適用

```sh
git clone https://github.com/retogo/dotfiles.git
cd dotfiles
./install.sh
```

`install.sh` は OS を判定して `darwin` / `linux` のいずれかの configuration を適用する。`home.username` と `home.homeDirectory` は flake 評価時に環境変数 `$USER` / `$HOME` から取得するため、`--impure` 付きで実行される（`install.sh` 内で指定済み）。

直接コマンドで実行する場合:

```sh
home-manager switch --flake .#darwin --impure   # macOS
home-manager switch --flake .#linux  --impure   # Linux
```

## 設定の変更

1. `home/` または `shell/` のファイルを編集
2. 新規ファイルを追加した場合は `git add` する
3. `./install.sh` で再適用

## 構成

| パス | 内容 |
|------|------|
| `flake.nix` | エントリポイント。darwin / linux の出し分け |
| `home/common.nix` | 共通パッケージ・zsh 設定 |
| `home/darwin.nix` | macOS 固有設定 |
| `home/linux.nix` | Linux 固有設定 |
| `shell/common.sh` | 共通シェル関数 |
| `shell/darwin.sh` | macOS 固有のシェル設定 |
| `shell/darwin-profile.sh` | macOS のログイン時設定 |

## パッケージの追加

`home/common.nix` の `home.packages` に追加する。macOS 固有なら `home/darwin.nix` に追加する。

```nix
home.packages = with pkgs; [
  # 追加したいパッケージ
  ripgrep
];
```

unfree パッケージは `flake.nix` の `allowUnfreePredicate` への追加も必要。

## devcontainer

VS Code の設定に以下を追加すると、コンテナ起動時に自動適用される:

```json
{
  "dotfiles.repository": "retogo/dotfiles",
  "dotfiles.installCommand": "./install.sh"
}
```
