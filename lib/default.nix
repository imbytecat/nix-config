{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
  ];

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

  # 网关专用 builder：单用户 root，不走 home-manager / fish / 1password / catppuccin / fonts，
  # 只共享 modules/shared/nix.nix（Lix + nix.settings + flake registry/nixPath）。
  # 用 username = "root" 复用 nix.nix 中的 trusted-users 写法（重复项 Nix 自动 dedupe）。
  mkGateway =
    {
      hostname,
      system ? "x86_64-linux",
      extraModules ? [ ],
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs sshKeys;
        username = "root";
      };
      modules = [
        ../modules/shared/nix.nix
        ../modules/gateway
        inputs.disko.nixosModules.disko
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };

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
