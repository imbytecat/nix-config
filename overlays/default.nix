{ inputs }:

inputs.nixpkgs.lib.composeManyExtensions [

  (final: prev: {
    comment-checker = final.callPackage ../pkgs/comment-checker { };
  })

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
      inherit (master) opencode;
    }
  )

]
