{
  description = "Multi-platform Nix configuration — nix-darwin + NixOS";

  # bootstrap 缓存有意重复 modules/shared/nix.nix：nixConfig 不能 import，稳态仍以后者为准。
  # nixos-anywhere 会另行转发目标机 nix.settings，justfile 不再复制。
  nixConfig = {
    extra-substituters = [
      # cache.nixos.org 国内镜像，沿用官方签名
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.numtide.com"
      "https://catppuccin.cachix.org"
      "https://attic.xuyh0120.win/lantian" # nix-cachyos-kernel
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Darwin 使用推进更快、aarch64 缓存命中更高的 nixpkgs-unstable。
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # cherry-studio 暂 pin 在 1.9.11 的缓存 revision；当前主线同版本依赖 insecure pnpm/Electron。
    # 主线切到无 insecure 依赖后，dry-run 确认缓存再删除此 pin。
    nixpkgs-pnpm-pin.url = "github:NixOS/nixpkgs/4c5fd5ac81ed3f63654e295d49552ca1dbc65447";

    # 不 follows nixpkgs，避免 cache.numtide.com miss。
    llm-agents.url = "github:numtide/llm-agents.nix";

    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    agent-browser = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # 不 follows nixpkgs，保留匹配内核 revision 的缓存。
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # taps 由 flake pin；非官方 tap 在 Darwin 模块标记 trusted。
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

    # 首装时网络脆弱，pin 入 lock 避免现场拉取 GitHub。
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
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

    # catppuccin/nix 无 Konsole port，直接挂官方 colorscheme。
    catppuccin-konsole = {
      url = "github:catppuccin/konsole";
      flake = false;
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      overlay = import ./overlays { inherit inputs; };
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      treefmtFor = system: inputs.treefmt-nix.lib.evalModule (pkgsFor system) ./treefmt.nix;
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
        awesome-pc = mylib.mkNixos {
          hostname = "awesome-pc";
          system = "x86_64-linux";
          username = "imbytecat";
          extraModules = [
            ./modules/nixos/boot/systemd-boot.nix
            ./modules/desktop/nixos.nix
            ./hosts/awesome-pc
          ];
        };

        homelab-server = mylib.mkServer {
          hostname = "homelab-server";
          system = "x86_64-linux";
          extraModules = [
            ./modules/nixos/boot/systemd-boot.nix
            ./hosts/homelab-server
          ];
        };

        mihomo-gateway = mylib.mkServer {
          hostname = "mihomo-gateway";
          system = "x86_64-linux";
          extraModules = [
            ./modules/nixos/boot/systemd-boot.nix
            ./modules/gateway
            ./hosts/mihomo-gateway
          ];
        };

        ovh-ks-5 = mylib.mkServer {
          hostname = "ovh-ks-5";
          system = "x86_64-linux";
          extraModules = [
            ./modules/nixos/boot/grub-raid.nix
            ./hosts/ovh-ks-5
          ];
        };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          # 上游 package.nix 仍读取 stdenv.isDarwin；修复后恢复直接 inherit。
          disko-install =
            (inputs.disko.packages.${system}.disko.override {
              stdenv = pkgs.stdenv // {
                isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
              };
            }).overrideAttrs
              (_old: {
                name = "disko-install";
              });
        in
        {
          inherit disko-install;
          inherit (inputs.nixos-anywhere.packages.${system}) nixos-anywhere;

          # release 分支资产会被上游重建并重新上传，hash 会随之变化，报 mismatch 就照 got 更新。
          kexec-installer = pkgs.fetchurl {
            url = "https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz";
            hash = "sha256-MFqeSStu9LTF7eZZKFfOrf7KtsFCcErNULepSIUFs+w=";
          };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          inherit (pkgs) orca-ide;
        }
      );

      overlays.default = overlay;

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.actionlint
              pkgs.just
              pkgs.nixd
              pkgs.statix
              pkgs.deadnix
              pkgs.nix-update
              pkgs.nvd
              pkgs.nix-tree
              (treefmtFor system).config.build.wrapper
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;

          # 仅强制求值 drvPath；丢弃 derivation 上下文，避免 Linux 真构建 Darwin 闭包。
          evalOnly =
            name: drvPath:
            pkgs.runCommand "eval-${name}" { } ''
              echo ${builtins.unsafeDiscardOutputDependency drvPath} > $out
            '';
        in
        {
          formatting = (treefmtFor system).config.build.check inputs.self;

          lint =
            pkgs.runCommand "lint"
              {
                nativeBuildInputs = [
                  pkgs.actionlint
                  pkgs.statix
                  pkgs.deadnix
                ];
              }
              ''
                cd ${inputs.self}
                actionlint .github/workflows/*.yml
                statix check
                # hardware-configuration.nix 由 nixos-generate-config 生成，不由我们维护
                deadnix --fail --exclude \
                  ./hosts/awesome-pc/hardware-configuration.nix \
                  ./hosts/ovh-ks-5/hardware-configuration.nix
                touch $out
              '';
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          eval-awesome-macbook-air = evalOnly "awesome-macbook-air" inputs.self.darwinConfigurations.awesome-macbook-air.system.drvPath;
          eval-awesome-pc = evalOnly "awesome-pc" inputs.self.nixosConfigurations.awesome-pc.config.system.build.toplevel.drvPath;
          eval-homelab-server = evalOnly "homelab-server" inputs.self.nixosConfigurations.homelab-server.config.system.build.toplevel.drvPath;
          eval-mihomo-gateway = evalOnly "mihomo-gateway" inputs.self.nixosConfigurations.mihomo-gateway.config.system.build.toplevel.drvPath;
          eval-ovh-ks-5 = evalOnly "ovh-ks-5" inputs.self.nixosConfigurations.ovh-ks-5.config.system.build.toplevel.drvPath;
        }
      );

      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);
    };
}
