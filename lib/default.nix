{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  # Shared home-manager configuration block
  homeManagerConfig =
    {
      username,
      sharedModules ? [ ],
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
          inputs.lazyvim.homeManagerModules.default
        ]
        ++ sharedModules;
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
      modules = [
        ../modules/shared
        ../modules/nixos
        inputs.home-manager.nixosModules.home-manager
        inputs.catppuccin.nixosModules.catppuccin
        inputs.sops-nix.nixosModules.sops
        (homeManagerConfig { inherit username; })
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
      modules = [
        ../modules/shared
        ../modules/darwin
        inputs.home-manager.darwinModules.home-manager
        (homeManagerConfig { inherit username; })
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };

}
