{
  pkgs,
  username,
  inputs,
  ...
}:

{
  nix.package = pkgs.lix;

  nix.settings = {
    substituters = [
      # 1. 官方主源 (priority=40)，覆盖最广
      "https://cache.nixos.org"
      # 2. nix-community：home-manager / nix-darwin 等社区项目产物
      "https://nix-community.cachix.org"
      # 3. unfree 包镜像（你 allowUnfree=true，覆盖 vscode/fonts 等）
      "https://nixpkgs-unfree.cachix.org"
      # 4. numtide：llm-agents.nix 每天构建的 opencode / skills 等推这里
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 信任 flake 自带的 nixConfig(extra-substituters),消除每次 switch 的
    # "ignoring untrusted flake configuration" warning。本仓自管自家 flake,安全可控
    accept-flake-config = true;
    warn-dirty = false;
    trusted-users = [
      "root"
      username
    ];
  };

  nix.channel.enable = false;

  # 让 legacy nixPath/CLI 跟随 flake 锁定的 nixpkgs
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
}
