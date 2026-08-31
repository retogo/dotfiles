{ pkgs, lib, ... }:

{
  home.stateVersion = "24.11";
  # Claude Code は auto update を利用するため Nix 管理外 (~/.local/bin)
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/node_modules/.bin"
    # bun link した CLI (~/.bun/bin/<cmd>) を使う
    "$HOME/.bun/bin"
    # 非対話プロセスから mise 管理のランタイムを解決させる
    "$HOME/.local/share/mise/shims"
  ];

  home.packages = with pkgs; [
    # Languages & Runtimes
    # node / bun / java は mise 管理（config/mise/config.toml）
    python3
    go
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
    codegraph
    gnupg
    firebase-tools
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    kubectl
    kubernetes-helm

    # Linter / Formatter
    # textlint はプリセットと node_modules を共有する必要があるため npm/package.json 管理
    dprint

    # CLI Utilities
    fd
    fzf
    yazi
    tree
    glow
    yq

    # LLM Runtime
    # llama-cpp は Darwin では metalSupport がデフォルト有効（GPU 推論が効く）。
    ollama
    llama-cpp
  ];

  programs.home-manager.enable = true;
  programs.starship.enable = true;

  # 設定の実体は config/mise/config.toml。globalConfig は空のままにする
  programs.mise = {
    enable = true;
    package = pkgs.mise;
  };

  programs.zsh = {
    enable = true;

    shellAliases = {
      lg = "lazygit";
      vi = "nvim";
      vim = "nvim";

      # Aikido Safe Chain: パッケージ取得時に悪性パッケージを検出するラッパー
      npm = "aikido-npm";
      npx = "aikido-npx";
      bun = "aikido-bun";
      bunx = "aikido-bunx";
      uv = "aikido-uv";
      uvx = "aikido-uvx";
    };

    sessionVariables = {
      EDITOR = "micro";
      VISUAL = "micro";
      # Ghostty は Claude Code の OSC 8 ハイパーリンク自動検出に含まれないため強制有効化
      FORCE_HYPERLINK = "1";
    };

    initContent = lib.mkBefore (builtins.readFile ../shell/common.sh);
  };

  # npm パッケージを package.json + package-lock.json で宣言管理
  home.file.".npm-global/package.json".source = ../npm/package.json;
  home.file.".npm-global/package-lock.json".source = ../npm/package-lock.json;

  # npm ci は lockfile 通りに node_modules を作り直すため冪等。
  # node は mise 管理で Nix profile に無いが、依存の lifecycle script が `node` を
  # PATH から起動するため、activation の間だけ nixpkgs の node を PATH に通す。
  # これで mise の導入状態に依存せず switch 単体で完結する。
  home.activation.npmGlobalInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
      export PATH="${pkgs.nodejs}/bin:$PATH"
      run ${pkgs.nodejs}/bin/npm ci --prefix "$HOME/.npm-global" --loglevel=error --no-fund --no-audit
    )
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
    "mise/config.toml".source = ../config/mise/config.toml;
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
