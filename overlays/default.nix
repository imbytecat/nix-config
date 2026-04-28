{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    comment-checker = final.callPackage ../pkgs/comment-checker { };
  })

  # unstable 滞后时从 master 借包
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
      # opencode 发版频繁
      inherit (master) opencode;
    }
  )

]
