#!/bin/bash
set -euo pipefail

# Nix を PATH に反映 (既にインストール済みなら)
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Nix のインストール (未インストール時のみ)
if ! command -v nix &>/dev/null; then
  curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --no-confirm
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# home-manager の適用
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG="darwin"
if [ "$(uname)" != "Darwin" ]; then
  if grep -qi microsoft /proc/version 2>/dev/null; then
    CONFIG="wsl2"
  else
    CONFIG="linux"
  fi
fi

# flake.nix が $USER / $HOME を builtins.getEnv で参照するため --impure が必要
nix run home-manager -- switch --flake "${DOTFILES_DIR}#${CONFIG}" -b backup --impure

# mise 管理のランタイム（config/mise/config.toml）を実体化する
"$HOME/.nix-profile/bin/mise" install

# コーディングエージェントは更新が速く各自の auto update に任せるため、Nix / mise 管理外で
# 公式のネイティブインストーラーから ~/.local/bin に入れる (未インストール時のみ)。
# ~/.local/bin を先に PATH に入れておき、インストーラーが ~/.zshrc (Nix store への
# 読み取り専用 symlink) に PATH を追記しようとするのを防ぐ
export PATH="$HOME/.local/bin:$PATH"

# Claude Code
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Codex CLI (CODEX_NON_INTERACTIVE: インストール後の "Start Codex now?" を出さない)
if ! command -v codex &>/dev/null; then
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
fi

# Antigravity CLI (コマンド名: agy)
if ! command -v agy &>/dev/null; then
  curl -fsSL https://antigravity.google/cli/install.sh | bash
fi

# zsh をログインシェルに設定 (Linux/WSL のみ)
if [ "$(uname)" != "Darwin" ]; then
  NIX_ZSH="$HOME/.nix-profile/bin/zsh"
  if [ -x "$NIX_ZSH" ]; then
    if ! grep -qxF "$NIX_ZSH" /etc/shells; then
      echo "$NIX_ZSH" | sudo tee -a /etc/shells >/dev/null
    fi
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$NIX_ZSH" ]; then
      chsh -s "$NIX_ZSH"
    fi
  fi
fi
