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
      # 4. numtide：treefmt-nix / devshell / nix-systems 小工具链
      "https://numtide.cachix.org"
      # 5. garnix CI：只对挂在它上面的 flake 有用，留底
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
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

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ inputs.self.overlays.default ];
  };
}
