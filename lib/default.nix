{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  # Shared home-manager configuration block
  homeManagerConfig = username: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs username;
      };
      users.${username} = import ../home;
    };
  };
in
{
  # ── NixOS host builder ──────────────────────────────
  mkNixos =
    {
      hostname,
      system,
      username,
      extraModules ? [ ],
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs hostname username;
      };
      modules =
        [
          ../modules/shared
          ../modules/nixos
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          (homeManagerConfig username)
          { networking.hostName = hostname; }
        ]
        ++ extraModules;
    };

  # ── nix-darwin host builder ─────────────────────────
  mkDarwin =
    {
      hostname,
      system,
      username,
      extraModules ? [ ],
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs hostname username;
      };
      modules =
        [
          ../modules/shared
          ../modules/darwin
          inputs.home-manager.darwinModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          (homeManagerConfig username)
          { networking.hostName = hostname; }
        ]
        ++ extraModules;
    };

  # ── Standalone Home Manager (no NixOS / no Darwin) ──
  mkHome =
    {
      system,
      username,
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {
        inherit inputs username;
        hostname = "standalone";
      };
      modules = [ ../home ];
    };
}
