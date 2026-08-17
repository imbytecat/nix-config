{ inputs }:

final: prev:
{
  # 临时取可评估且命中缓存的 cherry-studio revision；退出条件见 flake.nix。
  inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${prev.stdenv.hostPlatform.system})
    cherry-studio
    ;

  ttf-ms-win10 = final.callPackage ../pkgs/ttf-ms-win10 { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  orca-ide = final.callPackage ../pkgs/orca-ide { };
  rime-wanxiang-grammar = final.callPackage ../pkgs/rime-wanxiang-grammar { };
}
