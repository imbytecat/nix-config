{ lib, ... }:

let
  # 特性文件按 class（nixos / darwin / homeManager）向角色或 adapter 贡献模块，modules/hosts.nix 按名组合。
  # 名单写死：拼错的键会因选项不存在而求值失败，不会变成一段永不导入的配置。
  names = {
    nixos = [
      "base"
      "workstation"
      "desktop"
      "server"
      "gateway"
      "root-ssh"
      "qemu-guest"
      "grub-raid"
      "systemd-boot"
    ];
    darwin = [
      "base"
      "workstation"
      "desktop"
    ];
    homeManager = [
      "workstation"
      "desktop"
    ];
  };
in
{
  # 不用 flake-parts 的 flake.modules：它会成为 flake output，nix flake check 报 unknown output。
  options.aspects = lib.mapAttrs (
    _:
    lib.flip lib.genAttrs (
      _:
      lib.mkOption {
        type = lib.types.deferredModule;
        default = { };
      }
    )
  ) names;
}
