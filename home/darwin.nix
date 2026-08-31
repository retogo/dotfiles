{ lib, ... }:

{
  # jdk は mise 管理に移した（config/mise/config.toml）。

  programs.zsh.profileExtra = builtins.readFile ../shell/darwin-profile.sh;
  programs.zsh.initContent = lib.mkAfter (builtins.readFile ../shell/darwin.sh);

  xdg.configFile."ghostty/config".source = ../config/ghostty/config;
}
