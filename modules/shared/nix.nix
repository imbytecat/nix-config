{
  pkgs,
  inputs,
  ...
}:

{
  nix.package = pkgs.lix;

  nix.settings = {
    # 所有 host 的 substituters/公钥唯一真源（gateway 用 mkBefore 加性合并、非拷贝）。flake.nix
    # nixConfig 的 bootstrap 子集是有意重复：nixConfig 无法 import 单源。
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.numtide.com"
      "https://catppuccin.cachix.org"
      # devenv 自带 cache（镜像 cache.nixos.org + 缓存 devenv-nixpkgs/rolling），
      # 让 `devenv shell` 命中预构建产物而非本地编译。CLI 由 home/dev/devenv.nix 装。
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 信任 flake 自带的 nixConfig(extra-substituters),消除每次 switch 的
    # "ignoring untrusted flake configuration" warning。本仓自管自家 flake,安全可控
    accept-flake-config = true;
    warn-dirty = false;
    # trusted-users 不在这里设：上游默认已含 root，服务器（root-only）无需再加；
    # 日用机的普通用户由 modules/nixos/dev.nix 与 modules/darwin 各自追加。
  };

  nix.channel.enable = false;

  # 让 legacy nixPath/CLI 跟随 flake 锁定的 nixpkgs
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
}
