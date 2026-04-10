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

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (import ../../overlays) ];
  };
}
