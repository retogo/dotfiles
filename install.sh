#!/bin/bash
set -euo pipefail

# Nix のインストール
if ! command -v nix &>/dev/null; then
  curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --no-confirm
fi

# Nix を PATH に反映
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# home-manager の適用
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG="darwin"
if [ "$(uname)" != "Darwin" ]; then
  CONFIG="linux"
fi

# flake.nix が $USER / $HOME を builtins.getEnv で参照するため --impure が必要
nix run home-manager -- switch --flake "${DOTFILES_DIR}#${CONFIG}" -b backup --impure
