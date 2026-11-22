let
  settings =
    {
      pkgs,
      inputs,
      ...
    }:
    {
      nix.package = pkgs.lix;

      nix.settings = {
        # 稳态缓存真源；flake.nix 的 bootstrap 子集因 nixConfig 不能 import 而重复。
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://nixpkgs-unfree.cachix.org"
          "https://cache.numtide.com"
          "https://catppuccin.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
        ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # 信任本仓 flake nixConfig，避免每次 switch 交互确认。
        accept-flake-config = true;
        warn-dirty = false;
      };

      nix.channel.enable = false;

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };

  gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  trustUser =
    { username, ... }:
    {
      nix.settings.trusted-users = [ username ];
    };
in
{
  aspects.nixos.base = {
    imports = [ settings ];
    nix.gc = gc // {
      dates = "weekly";
    };
  };

  aspects.darwin.base = {
    imports = [ settings ];
    nix.gc = gc // {
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 15;
      };
    };
  };

  aspects.nixos.daily = trustUser;
  aspects.darwin.daily = trustUser;

  aspects.nixos.server.nix.optimise.automatic = true;
}
