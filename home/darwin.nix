{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    blender
  ];

  # symlink の .app は Spotlight にインデックスされずアプリ一覧に出ないため、コピーで配置する
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;

  programs.zsh.profileExtra = builtins.readFile ../shell/darwin-profile.sh;
  programs.zsh.initContent = lib.mkAfter (builtins.readFile ../shell/darwin.sh);

  xdg.configFile."ghostty/config".source = ../config/ghostty/config;
}
