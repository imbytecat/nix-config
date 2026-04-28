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
      "https://cache.nixos.org"
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
