{ lib, pkgs, ... }:

{
  # Determinate Nix manages the daemon on macOS
  nix.enable = !pkgs.stdenv.isDarwin;

  nix.settings = lib.mkIf (!pkgs.stdenv.isDarwin) {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays) ];
  };
}
