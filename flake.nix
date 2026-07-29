{
  description = "Multi-platform Nix configuration — nix-darwin + NixOS";

  # 首次 bootstrap 时让 nix 也走这些 cache（系统 nix.settings 在 switch 后才生效）。
  # 与 modules/shared/nix.nix 的 nix.settings 有意重复且无法单源（nixConfig 不能 import）：
  # 改缓存/公钥两处都要动。这里是 bootstrap 子集，稳态真源在 nix.settings。
  # 三条 bootstrap 路径都吃这里：Live ISO 的 `nix run --accept-flake-config`、
  # `nix run .#nixos-anywhere`（装网关时本机往往正没代理）、以及 .envrc 的 direnv。
  # 注意 nixos-anywhere 另有 machineSubstituters：它会把目标 host 的 nix.settings
  # 喂给 installer，所以 justfile 里不需要再抄一份。
  nixConfig = {
    extra-substituters = [
      # cache.nixos.org 的国内镜像，签名同为 cache.nixos.org-1（默认已信任，无需配公钥）
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.numtide.com"
      "https://catppuccin.cachix.org"
      "https://attic.xuyh0120.win/lantian" # nix-cachyos-kernel (xddxdd)
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  inputs = {
    # nixos-unstable branch: 走 NixOS hydra 集成测试再推进，给本仓 NixOS host 用
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixpkgs-unstable branch: 推进更快、aarch64-darwin 命中率高于 nixos-unstable，
    # darwin host 显式用这条。不是 darwin 专属，谁想跟更新都可以来这边
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # pnpm CVE 连坐：pin 到标记前最后一个有 hydra cache 的 revision，overlay 从此 inherit
    # cherry-studio（vue-language-server 已在上游摆脱 insecure pnpm，2026-07 移回主 nixpkgs）。
    nixpkgs-pnpm-pin.url = "github:NixOS/nixpkgs/49a4bd0573c376468dd7996ddb6f9fa31d8c4d97";

    # AI coding agents (opencode, skills, ...)，每天构建并 push 到 cache.numtide.com。
    # 消费方式：inputs.llm-agents.packages.${system}.*（上游推荐；已无 overlays 输出）。
    # 故意不 follows nixpkgs，否则 binary cache 就 miss 了。
    llm-agents.url = "github:numtide/llm-agents.nix";

    # CachyOS 内核（awesome-pc 桌面）。release 分支 = Hydra CI 通过且已推 binary cache 的版本。
    # 故意不 follows nixpkgs：kernel patch 需匹配 nixpkgs 内核版本，且 pinned overlay 要自带 revision 才命中 cache。
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Homebrew tap 声明式 pin 到 flake input，避开 brew update 运行时漂移。brew 本体由
    # nix-homebrew 自带 brew-src（6.x）提供，随 just update 升级。非官方 tap 需在
    # modules/darwin/default.nix 标 trusted=true（brew 6.0 的 HOMEBREW_REQUIRE_TAP_TRUST）。
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

    # 首装工具也 pin 进 lock：`nix run github:...` 每次都要现取 GitHub，而首装的典型场景
    # 恰恰是「网关本身还没起来/正在重装」，本机没代理。pin 后走 flake.lock + binary cache。
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-starship = {
      url = "github:catppuccin/starship";
      flake = false;
    };

    # Konsole 的 Catppuccin 配色：catppuccin/nix 没有 konsole port，autoEnable 跳过它，
    # 故手动挂官方 colorscheme（见 home/desktop/plasma.nix）。同 starship 走 flake=false + flake.lock 跟随上游。
    catppuccin-konsole = {
      url = "github:catppuccin/konsole";
      flake = false;
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # KDE Plasma 6 声明式设置（home-manager 模块）。只在 Linux 桌面生效：home/ 按
    # stdenv.isLinux 导入 home/desktop，再按系统是否启用 Plasma 6（osConfig）激活。
    # follows nixpkgs + home-manager 与本仓一致，避免额外实例化。
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
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

      packages.x86_64-linux = {
        # Live 本机安装直接运行本仓锁定的官方 disko-install
        inherit (inputs.disko.packages.x86_64-linux) disko-install;
        # 远程首装（just install）走 lock 住的这份，不再 `nix run github:`
        inherit (inputs.nixos-anywhere.packages.x86_64-linux) nixos-anywhere;
      };

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
