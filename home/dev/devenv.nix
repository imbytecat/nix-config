{ pkgs, ... }:

{
  # devenv CLI：per-project 声明式开发环境（devenv shell / up / test）。
  # 这里只装 CLI；binary cache（devenv.cachix.org）在 modules/shared/nix.nix
  # 的 nix.settings 里配，全机共享。不放进 flake.nix 的 bootstrap nixConfig——
  # 那块只为构建本仓系统服务，devenv cache 与系统构建无关。
  home.packages = [ pkgs.devenv ];
}
