{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    comment-checker = final.callPackage ../pkgs/comment-checker { };
  })

  # 跟随 master 的包（unstable channel 太慢时用）
  (
    final: prev:
    let
      pkgsFrom =
        flake:
        import flake {
          inherit (prev.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      master = pkgsFrom inputs.nixpkgs-master;
    in
    {
      # opencode 发版频繁，跟 master 更新更快
      inherit (master) opencode;

      # https://github.com/NixOS/nixpkgs/pull/510439
      # unstable channel 的 nushell 在 darwin 上编译失败，PR 已合并 master，
      # 待 unstable channel 推进后可删除此行。
      inherit (master) nushell;
    }
  )

]
