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

  # 远程 NixOS 主机专用 builder（如 mihomo-gateway，未来其它服务器同样适用）：
  # - 仅共享 modules/shared/nix.nix（Lix + nix.settings + flake registry/nixPath）
  # - 不导入 modules/shared/default.nix / modules/nixos / home-manager / catppuccin / fonts，
  #   避免日用模块（fish / 1password / docker / homebrew 那些）污染服务器
  # - 自动拉 inputs.disko.nixosModules.disko；host 直接写 disko.devices.* 即可
  # - 部署套路：`just install <host> <ip>` 首装、`just deploy <host> <ip>` 远程更新
  # - username 固定为 "root"：复用 nix.nix 中 trusted-users 的写法（Nix 自动 dedupe）
  #
  # 加新服务器的步骤：
  #   1. 写 modules/<purpose>/  （服务相关的 NixOS 配置，如 mihomo + tproxy）
  #   2. 写 hosts/<host>/{default,disko}.nix （boot/openssh/timezone/disko 等 host-level）
  #   3. 在 flake.nix 添加：<host> = mylib.mkServer { hostname = "..."; extraModules = [ ./hosts/<host> ]; };
  #   4. just install <host> <ip>  （首装）；之后 just deploy <host> <ip>  （更新）
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
        ../modules/shared
        ../modules/darwin
        inputs.home-manager.darwinModules.home-manager
        (homeManagerConfig username)
        { networking.hostName = hostname; }
      ]
      ++ extraModules;
    };
}
