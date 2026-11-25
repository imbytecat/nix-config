{
  description = "Multi-platform Nix configuration — nix-darwin + NixOS";

  # bootstrap 缓存有意重复 modules/nix.nix：nixConfig 不能 import，稳态仍以后者为准。
  # nixos-anywhere 会另行转发目标机 nix.settings，justfile 不再复制。
  nixConfig = {
    extra-substituters = [
      # cache.nixos.org 国内镜像，沿用官方签名
      "https://mirrors.ustc.edu.cn/nix-channels/store"
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Darwin 使用推进更快、aarch64 缓存命中更高的 nixpkgs-unstable。
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # 不 follows nixpkgs，避免 cache.numtide.com miss。
    llm-agents.url = "github:numtide/llm-agents.nix";

    models-dev = {
      url = "github:anomalyco/models.dev/dev";
      flake = false;
    };

    # 插件链接系统 fcitx5，必须 follows；上游无二进制缓存，总在本地编译。
    wowtype = {
      url = "github:Gloridust/WowType/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # taps 由 flake pin；非官方 tap 在 Darwin 模块标记 trusted。
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    # homebrew-core 跟上游 master，新的 bottle DSL 只有最新 release 的 brew 认；nix-homebrew 自带的 brew-src 跟得慢。
    # `just update` 先把 tag 改成最新 release 再更新 lock。
    brew-src = {
      url = "github:Homebrew/brew/7.0.16";
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

    # 首装时网络脆弱，pin 入 lock 避免现场拉取 GitHub。
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };

    # 只取 kexec 安装镜像的 NixOS 模块；镜像由本仓 nixpkgs 按目标机内核构建。
    nixos-images = {
      url = "github:nix-community/nixos-images";
      flake = false;
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

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # modules/ 下每个 .nix 都是 flake-parts 模块；路径含 /_ 的是被 import 的数据或辅助函数。
      imports = builtins.filter (
        path: lib.hasSuffix ".nix" (toString path) && !lib.hasInfix "/_" (toString path)
      ) (lib.filesystem.listFilesRecursive ./modules);
    };
}
