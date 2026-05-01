{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      darwinSystem = "aarch64-darwin";
      linuxSystem = "x86_64-linux";

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "terraform"
          ];
      };

      # ローカル環境変数からユーザー名と HOME を取得し、リポジトリに固定値を含めない。
      # 評価には --impure が必要（install.sh で渡している）。
      identity = {
        home.username = builtins.getEnv "USER";
        home.homeDirectory = builtins.getEnv "HOME";
      };

      mkHome = system: modules: home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs system;
        modules = modules ++ [ identity ];
      };
    in
    {
      homeConfigurations = {
        "darwin" = mkHome darwinSystem [
          ./home/common.nix
          ./home/darwin.nix
        ];

        "linux" = mkHome linuxSystem [
          ./home/common.nix
          ./home/linux.nix
        ];
      };
    };
}
