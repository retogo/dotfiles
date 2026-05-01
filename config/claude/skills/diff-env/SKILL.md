---
name: diff-env
description: 現在のmac環境とdotfilesリポジトリの設定ファイル差分を調べる
allowed-tools: Bash, Read, Glob, Grep
---

# 環境差分チェック

現在のmac環境とdotfilesリポジトリの差分を調査し、レポートする。

## 手順

1. **シンボリックリンクの状態確認**: `install.sh` で管理している全ファイルについて、シンボリックリンクか実ファイルかを `ls -la` で確認する
2. **設定ファイルの内容差分**: 以下の各ファイルについて `diff` で比較する
   - `~/.zshrc` vs `.zshrc`
   - `~/.bashrc` vs `.bashrc`（Linuxの場合のみ）
   - `~/.config/nvim/` vs `.config/nvim/`
   - `~/.config/zellij/` vs `.config/zellij/`
   - `~/.config/tmux/` vs `.config/tmux/`
   - `~/.config/starship.toml` vs `.config/starship.toml`
   - `~/Library/Application Support/lazygit/config.yml` vs `.config/lazygit/config.yml`（macOS）
   - `~/Library/Application Support/com.mitchellh.ghostty/config` vs `.config/ghostty/config`（macOS）
   - `~/.claude/statusline-command.sh` vs `.claude/statusline-command.sh`
3. **brewパッケージの差分**: `brew list --formula` の結果と `install.sh` の `install_core` / `install_extras` 両関数内の `brew install` 行を比較し、dotfilesで管理されていないツールを列挙する
4. **レポート出力**: 以下の形式でまとめる
   - シンボリックリンクが未適用のファイル一覧
   - 内容に差分があるファイルと具体的な違い
   - mac側にあってdotfilesにないもの（環境→dotfilesへの同期が必要）
   - dotfilesにあってmac側にないもの（dotfiles→環境への適用が必要）

## 管理対象外ファイル（差分レポートで無視する）

以下は自動生成・ロックファイルのためdotfilesの管理対象外。差分として検出されても「同期不要」として扱う。

- nvim: `lazy-lock.json`, `lazyvim.json`, `.neoconf.json`, `stylua.toml`, `LICENSE`, `README.md`, `lua/plugins/example.lua`
- その他ツールが自動生成するロックファイル・キャッシュ全般

## 注意事項

- **並列Bash実行時のエラー伝播**: 並列で複数のBashツールを呼び出した場合、1つでもexit code非0で失敗すると残りの兄弟呼び出しが全て `Sibling tool call errored` でキャンセルされる。対策として:
  - 存在しないファイルを含む可能性がある `ls -la` は単独で実行する
  - `diff` コマンドには `2>&1 || true` を付けて常にexit code 0を返すようにする
  - 失敗する可能性があるコマンドと安全なコマンドを同じ並列バッチに混ぜない
