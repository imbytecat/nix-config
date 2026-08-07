{ inputs }:

final: _: {
  # 临时取可评估且命中缓存的 cherry-studio revision；退出条件见 flake.nix。
  inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
    cherry-studio
    ;
}
