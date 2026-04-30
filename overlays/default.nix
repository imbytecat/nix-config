{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    comment-checker = final.callPackage ../pkgs/comment-checker { };
  })

  # 通过 pkgs.llm-agents.<name> 访问，cache 命中靠 llm-agents 自锁的 nixpkgs revision
  inputs.llm-agents.overlays.default

]
