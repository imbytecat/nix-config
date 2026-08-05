{ inputs }:

final: _: {
  # 临时取旧 revision 的 cherry-studio；退出条件见 flake.nix。
  inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
    cherry-studio
    ;
}
