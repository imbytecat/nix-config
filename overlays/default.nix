{ inputs }:

final: _: {
  # 从 pin 的旧 revision 取 insecure-pnpm 受害包（原因/退出条件见 flake.nix nixpkgs-pnpm-pin 注释）
  inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
    cherry-studio
    ;
}
