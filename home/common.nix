{ pkgs, lib, ... }:

{
  home.stateVersion = "24.11";
  # Claude Code は auto update を利用するため Nix 管理外 (~/.local/bin)
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/node_modules/.bin"
  ];

  home.packages = with pkgs; [
    # Languages & Runtimes
    nodejs
    python3
    go
    bun
    rustup

    # Dev Tools
    uv
    gh
    ghq
    glab
    git
    delta
    neovim
    micro
    tmux
    zellij
    lazygit
    terraform
    dotenvx
    devcontainer
    opencode
    gnupg
    firebase-tools
    google-cloud-sdk

    # Linter / Formatter
    (textlint.withPackages [
      textlint-rule-preset-ja-technical-writing
      textlint-rule-preset-ja-spacing
    ])
    dprint

    # CLI Utilities
    fd
    fzf
    yazi
    tree
    glow
    yq
    ollama
  ];

  programs.home-manager.enable = true;
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      lg = "lazygit";
      vi = "nvim";
      vim = "nvim";
    };

    sessionVariables = {
      EDITOR = "micro";
      VISUAL = "micro";
    };

    initContent = lib.mkBefore (builtins.readFile ../shell/common.sh);
  };

  # nixpkgs に無い npm パッケージを package.json で宣言管理
  home.file.".npm-global/package.json".source = ../npm/package.json;

  home.activation.npmGlobalInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.nodejs}/bin/npm install --prefix "$HOME/.npm-global" --silent --no-fund --no-audit
  '';

  # dotfiles
  home.file.".gitconfig".source = ../config/.gitconfig;
  home.file.".gitignore_global".source = ../config/.gitignore_global;
  home.file.".claude/statusline-command.sh" = {
    source = ../config/claude/statusline-command.sh;
    executable = true;
  };
  home.file.".claude/skills/diff-env/SKILL.md".source = ../config/claude/skills/diff-env/SKILL.md;
  home.file.".npmrc".source = ../config/.npmrc;
  home.file.".textlintrc.json".source = ../config/.textlintrc.json;

  xdg.configFile = {
    "starship.toml".source = ../config/starship.toml;
    "lazygit/config.yml".source = ../config/lazygit/config.yml;
    "markdownlint/.markdownlint.json".source = ../config/markdownlint/.markdownlint.json;
    "dprint/dprint.jsonc".source = ../config/dprint/dprint.jsonc;
    "uv/uv.toml".source = ../config/uv/uv.toml;
    "zellij/config.kdl".source = ../config/zellij/config.kdl;
    "tmux/tmux.conf".source = ../config/tmux/tmux.conf;
    "tmux/rainbow-border.sh" = {
      source = ../config/tmux/rainbow-border.sh;
      executable = true;
    };
    "nvim" = {
      source = ../config/nvim;
      recursive = true;
    };
  };
}
