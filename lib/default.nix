{ inputs }:

let
  inherit (inputs.nixpkgs) lib;

  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
  ];

  # imports 阶段只能用 specialArg system；pkgs 依赖 config 会递归。
  homeManagerConfig =
    { username, system }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        overwriteBackup = true;
        sharedModules = [
          inputs.lazyvim.homeManagerModules.default
        ];
        extraSpecialArgs = {
          inherit inputs username system;
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
        ../modules/nixos/base.nix
        ../modules/nixos/dev.nix
        inputs.home-manager.nixosModules.home-manager
        inputs.catppuccin.nixosModules.catppuccin
        (homeManagerConfig { inherit username system; })
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };

  # 服务器只叠 server.nix 与 disko，避免日用和 Home Manager 闭包。
  mkServer =
    {
      hostname,
      system,
      extraModules ? [ ],
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs sshKeys;
      };
      modules = [
        ../modules/nixos/server.nix
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
        # Darwin 显式用 nixpkgs-unstable，避免 nix-darwin lib 与 registry 设置冲突。
        {
          nixpkgs.pkgs = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.self.overlays.default ];
          };
        }
        ../modules/shared
        ../modules/darwin
        inputs.home-manager.darwinModules.home-manager
        (homeManagerConfig { inherit username system; })
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };
}
