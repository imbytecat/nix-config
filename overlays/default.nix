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
  # nixpkgs 仍是 18.0.10；主线追平 18.1.0 后删除此 override。
  rime-wanxiang = prev.rime-wanxiang.overrideAttrs (old: {
    version = "18.1.0";
    src = old.src.override {
      tag = "v18.1.0";
      hash = "sha256-R+prsv6bNprGOwxZ1OO6e7LXijvwwouv+iZnC0Z1uaM=";
    };
  });
  rime-wanxiang-grammar = final.callPackage ../pkgs/rime-wanxiang-grammar { };
}
