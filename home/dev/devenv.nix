{ pkgs, ... }:

{
  # devenv CLI：per-project 声明式开发环境。这里只装 CLI；binary cache（devenv.cachix.org）
  # 在 modules/shared/nix.nix 全机共享，不放 flake.nix bootstrap nixConfig（那只为构建本仓系统）。
  home.packages = [ pkgs.devenv ];
}
