{ pkgs, ... }:

{
  nix.package = pkgs.lix;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  # 禁用 channels — 仅使用 flakes
  nix.channel.enable = false;

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays) ];
  };
}
