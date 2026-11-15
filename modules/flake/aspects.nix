{ lib, ... }:

{
  # 特性文件按 class（nixos / darwin / homeManager）向角色 aspect 贡献模块，modules/hosts.nix 按角色组合。
  # 不用 flake-parts 的 flake.modules：它会成为 flake output，nix flake check 报 unknown output。
  options.aspects = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
    default = { };
  };
}
