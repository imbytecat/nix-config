{ config, inputs, ... }:

let
  inherit (config) aspects;

  username = "imbytecat";
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
  ];

  # 机器事实（硬件、磁盘、单机覆盖）在 hosts/<host>；flake attr、目录与 hostName 同名。
  machine = hostname: [
    ../hosts/${hostname}
    { networking.hostName = hostname; }
  ];

  darwin =
    hostname: system: roles:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs username sshKeys; };
      modules = [
        # Darwin 用推进更快、aarch64 缓存命中更高的 nixpkgs-unstable；显式传入避免 nix-darwin lib 与 registry 设置冲突。
        {
          nixpkgs.pkgs = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
            overlays = [ config.flake.overlays.default ];
          };
        }
        aspects.darwin.base
        aspects.darwin.workstation
      ]
      ++ roles
      ++ machine hostname;
    };

  workstation =
    hostname: system: roles:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs username sshKeys; };
      modules = [
        aspects.nixos.base
        aspects.nixos.workstation
      ]
      ++ roles
      ++ machine hostname;
    };

  # 生产服务器只有 root 账号，因此不传 username。
  server =
    hostname: roles:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs sshKeys; };
      modules = [
        aspects.nixos.base
        aspects.nixos.server
      ]
      ++ roles
      ++ machine hostname;
    };
in
{
  flake.darwinConfigurations = {
    awesome-macbook-air = darwin "awesome-macbook-air" "aarch64-darwin" [ aspects.darwin.desktop ];
  };

  flake.nixosConfigurations = {
    awesome-devbox = workstation "awesome-devbox" "x86_64-linux" [
      aspects.nixos.grub-raid
      aspects.nixos.root-ssh
    ];

    awesome-pc = workstation "awesome-pc" "x86_64-linux" [
      aspects.nixos.desktop
      aspects.nixos.systemd-boot
    ];

    homelab-server = server "homelab-server" [
      aspects.nixos.qemu-guest
      aspects.nixos.systemd-boot
    ];

    mihomo-gateway = server "mihomo-gateway" [
      aspects.nixos.gateway
      aspects.nixos.qemu-guest
      aspects.nixos.systemd-boot
    ];

    ovh-ks-5 = server "ovh-ks-5" [ aspects.nixos.grub-raid ];
  };

  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      # 仅强制求值 drvPath；丢弃 derivation 上下文，避免 Linux 真构建 Darwin 闭包。
      evalOnly =
        name: drvPath:
        lib.nameValuePair "eval-${name}" (
          pkgs.runCommand "eval-${name}" { } ''
            echo ${builtins.unsafeDiscardOutputDependency drvPath} > $out
          ''
        );
    in
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") (
        lib.mapAttrs' (
          name: host: evalOnly name host.config.system.build.toplevel.drvPath
        ) config.flake.nixosConfigurations
        // lib.mapAttrs' (name: host: evalOnly name host.system.drvPath) config.flake.darwinConfigurations
      );
    };
}
