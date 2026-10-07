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
