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

    # 声明式 pin Homebrew 本体 + tap 版本,避开 brew update 漂移。
    # brew-src 提为顶层 input 并 pin 死 5.1.14,nix-homebrew.inputs.brew-src 用 follows 引它,
    # 绕过 5.1.15+ 的 --cleanup 弃用和 HOMEBREW_REQUIRE_TAP_TRUST 强制。
    # 必须显式 pin,否则 just update 升 nix-homebrew 会把 brew 顺带拖到 6.x。
    # 上游 https://github.com/nix-darwin/nix-darwin/pull/1789 合并后可解 pin 升 brew 6.x。
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-homebrew.inputs.brew-src.follows = "brew-src";
    brew-src = {
      url = "github:Homebrew/brew/5.1.14";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-goooler = {
      url = "github:goooler/homebrew-repo";
      flake = false;
    };
    homebrew-imbytecat = {
      url = "github:imbytecat/homebrew-tap";
      flake = false;
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
