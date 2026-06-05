{
  description = "Multi-platform Nix configuration — nix-darwin + NixOS";

  # 首次 bootstrap 时让 nix 也走这些 cache（系统 nix.settings 在 switch 后才生效）
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    # nixos-unstable branch: 走 NixOS hydra 集成测试再推进，给本仓 NixOS host 用
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixpkgs-unstable branch: 推进更快、aarch64-darwin 命中率高于 nixos-unstable，
    # darwin host 显式用这条。不是 darwin 专属，谁想跟更新都可以来这边
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # AI coding agents (opencode, skills, ...)，每天构建并 push 到 cache.numtide.com
    # 故意不 follows nixpkgs，否则 binary cache 就 miss 了
    llm-agents.url = "github:numtide/llm-agents.nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      mylib = import ./lib { inherit inputs; };
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      darwinConfigurations = {
        awesome-mac-mini = mylib.mkDarwin {
          hostname = "awesome-mac-mini";
          system = "aarch64-darwin";
          username = "imbytecat";
          extraModules = [ ./hosts/awesome-mac-mini ];
        };

        awesome-macbook-air = mylib.mkDarwin {
          hostname = "awesome-macbook-air";
          system = "aarch64-darwin";
          username = "imbytecat";
          extraModules = [ ./hosts/awesome-macbook-air ];
        };
      };

      nixosConfigurations = {
        # ── desktop ─────────────────────────────────────────
        awesome-pc = mylib.mkNixos {
          hostname = "awesome-pc";
          system = "x86_64-linux";
          username = "imbytecat";
          extraModules = [ ./hosts/awesome-pc ];
        };

        # ── server ──────────────────────────────────────────
        mihomo-gateway = mylib.mkServer {
          hostname = "mihomo-gateway";
          system = "x86_64-linux";
          extraModules = [
            ./modules/gateway
            ./hosts/mihomo-gateway
          ];
        };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) comment-checker;
        }
      );

      overlays.default = import ./overlays { inherit inputs; };

      # `nix develop` 入口：把仓库需要的 CLI 工具都拉齐，不依赖宿主已装 home-manager
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              just
              jq
              nixfmt
              nixd
              statix
              nvd
            ];
          };
        }
      );

      # `nix fmt` 入口
      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt);
    };
}
