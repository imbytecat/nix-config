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
    }
  )

]
