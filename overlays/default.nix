{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    # 从 pin 的旧 revision 取 insecure-pnpm 受害包（原因/退出条件见 docs/adr/0002-pnpm-pin.md）
    inherit (inputs.nixpkgs-pnpm-pin.legacyPackages.${final.stdenv.hostPlatform.system})
      cherry-studio
      vue-language-server
      ;
  })

  # 通过 pkgs.llm-agents.<name> 访问，cache 命中靠 llm-agents 自锁的 nixpkgs revision
  inputs.llm-agents.overlays.default

]
