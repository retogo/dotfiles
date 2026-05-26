{ pkgs, lib, ... }:

let
  # Notion CLI (ntn.dev) は nixpkgs に無いため自前で derivation 化。
  # 新バージョン追従: version を上げ、4 プラットフォーム分の sha256 を
  #   curl -fsSL https://ntn.dev/releases/v<X.Y.Z>/ntn-<target>.tar.gz.sha256
  # で取得して差し替える。
  ntn =
    let
      version = "0.14.1";
      sources = {
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          sha256 = "458eb3a7e50b26e2a45e60475902210e54b14812e23c64142489409dd2966c32";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          sha256 = "3bc751cc9cc42e1dfceb927bd6debf800ef671c98d6deee264f48f9ac6979702";
        };
        x86_64-linux = {
          target = "x86_64-unknown-linux-musl";
          sha256 = "5773820dccbdbf362c2cc5c0ffd5af3e0d4a244e404f80cdff66635633b8e64d";
        };
        aarch64-linux = {
          target = "aarch64-unknown-linux-musl";
          sha256 = "49b3674d2c017c0e9291af82c0425ab7c27e8da066a1cc98a863213986afbb83";
        };
      };
      info =
        sources.${pkgs.stdenv.hostPlatform.system}
          or (throw "ntn: unsupported platform ${pkgs.stdenv.hostPlatform.system}");
    in
    pkgs.stdenv.mkDerivation {
      pname = "ntn";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://ntn.dev/releases/v${version}/ntn-${info.target}.tar.gz";
        sha256 = info.sha256;
      };

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;
      dontPatchELF = true;

      installPhase = ''
        runHook preInstall
        install -Dm0755 ntn $out/bin/ntn
        runHook postInstall
      '';

      meta = {
        description = "Notion CLI";
        homepage = "https://ntn.dev";
        platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      };
    };
in
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
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    kubectl
    kubernetes-helm
    ntn

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
