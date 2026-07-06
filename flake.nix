{
  description = "Multi-platform Nix configuration — nix-darwin + NixOS";

  # 首次 bootstrap 时让 nix 也走这些 cache（系统 nix.settings 在 switch 后才生效）
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.numtide.com"
      "https://catppuccin.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    ];
  };

  inputs = {
    # nixos-unstable branch: 走 NixOS hydra 集成测试再推进，给本仓 NixOS host 用
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixpkgs-unstable branch: 推进更快、aarch64-darwin 命中率高于 nixos-unstable，
    # darwin host 显式用这条。不是 darwin 专属，谁想跟更新都可以来这边
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # cherry-studio 临时 pin：nixpkgs 2026-06-27 起把 pnpm 10.29.2 标记 insecure（CVE），
    # 而 cherry-studio 的 electron-builder <26.8.2 用不了新 pnpm（pnpm#10601），被迫连坐。
    # stable 也不行（1.7.9 依赖 insecure 的 electron-38）。pin 到标记前最后一个
    # 有 hydra cache 的 revision（1.9.9，2026-06-12）：无豁免、无本地 electron 编译。
    # 退出条件：nixpkgs 的 cherry-studio 升到 electron-builder >=26.8.2 后删除此 input。
    nixpkgs-cherry-studio.url = "github:NixOS/nixpkgs/49a4bd0573c376468dd7996ddb6f9fa31d8c4d97";

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

    # Homebrew tap 版本声明式管理,避开 brew update 运行时漂移。
    # brew 本体不再顶层写死:nix-darwin PR #1789 合并后(见 input nix-darwin)activation
    # 改用 brew 6.x 的 `--force-cleanup` 并支持 Brewfile `trusted: true`,nix-homebrew
    # 自带的 brew-src 已是 6.x,随 just update 升 nix-homebrew 一起走即可,无需 follows 覆盖。
    # 非官方 tap 需在 modules/darwin/default.nix 标 trusted=true 满足
    # HOMEBREW_REQUIRE_TAP_TRUST(brew 6.0 默认开)。
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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

    catppuccin-starship = {
      url = "github:catppuccin/starship";
      flake = false;
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
          extraModules = [
            ./modules/desktop/darwin.nix
            ./hosts/awesome-mac-mini
          ];
        };

        awesome-macbook-air = mylib.mkDarwin {
          hostname = "awesome-macbook-air";
          system = "aarch64-darwin";
          username = "imbytecat";
          extraModules = [
            ./modules/desktop/darwin.nix
            ./hosts/awesome-macbook-air
          ];
        };
      };

      nixosConfigurations = {
        # ── desktop（桌面场景：base + desktop/nixos.nix）────────
        awesome-pc = mylib.mkNixos {
          hostname = "awesome-pc";
          system = "x86_64-linux";
          username = "imbytecat";
          extraModules = [
            inputs.disko.nixosModules.disko
            ./modules/desktop/nixos.nix
            ./hosts/awesome-pc
          ];
        };

        # ── headless dev（无头开发场景：仅 base，不导入 desktop/nixos.nix）
        # 新增无头开发机时：mkNixos + hosts/<host>，extraModules 不加 desktop 即可

        # ── server（服务器场景：mkServer，root-only，不走 home-manager）
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
