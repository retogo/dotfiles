{ pkgs, ... }:

{
  # wslu は nixpkgs から削除されたため、wsl-open で Windows 側のブラウザを開く
  home.packages = with pkgs; [
    wsl-open
  ];

  programs.zsh.sessionVariables = {
    BROWSER = "wsl-open";
  };
}
