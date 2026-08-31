{ lib, ... }:

{
  programs.zsh.profileExtra = builtins.readFile ../shell/darwin-profile.sh;
  programs.zsh.initContent = lib.mkAfter (builtins.readFile ../shell/darwin.sh);

  xdg.configFile."ghostty/config".source = ../config/ghostty/config;
}
