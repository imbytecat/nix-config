{ pkgs, username, ... }:

{
  nix.package = pkgs.lix;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://cache.garnix.io"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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

  # 禁用 channels — 仅使用 flakes
  nix.channel.enable = false;

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays) ];
  };
}
