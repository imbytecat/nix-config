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

  # 远程 NixOS 服务器 builder：仅复用 modules/shared/nix.nix，不导入
  # modules/shared/default.nix / modules/nixos / home-manager / catppuccin，
  # 避免日用模块（fish / 1password / docker）污染服务器。自动拉 disko。
  mkServer =
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
        # 显式注入 nixpkgs-darwin 实例化的 pkgs（aarch64-darwin 命中率高于 nixos-unstable）
        # 不走 nix-darwin.inputs.nixpkgs.follows 是为了避免 nix-darwin 内部 lib 与
        # modules/shared/nix.nix 的 nix.registry 设置冲突。参考 ryan4yin/nix-config。
        {
          nixpkgs.pkgs = import inputs.nixpkgs-darwin {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.self.overlays.default ];
          };
        }
        ../modules/shared
        ../modules/darwin
        inputs.home-manager.darwinModules.home-manager
        (homeManagerConfig username)
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };
}
