{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
  ];

  # 共享的 Home Manager 配置块
  homeManagerConfig = username: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bak";
      sharedModules = [
        inputs.lazyvim.homeManagerModules.default
      ];
      extraSpecialArgs = {
        inherit inputs username;
      };
      users.${username} = import ../home;
    };
  };
in
{
  # ── NixOS 主机构建器 ─────────────────────────────────
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
        inherit
          inputs
          hostname
          username
          sshKeys
          ;
      };
      modules = [
        ../modules/shared
        ../modules/nixos
        inputs.home-manager.nixosModules.home-manager
        inputs.catppuccin.nixosModules.catppuccin
        (homeManagerConfig username)
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };

  # ── nix-darwin 主机构建器 ────────────────────────────
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
        inherit
          inputs
          hostname
          username
          sshKeys
          ;
      };
      modules = [
        ../modules/shared
        ../modules/darwin
        inputs.home-manager.darwinModules.home-manager
        (homeManagerConfig username)
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };

}
