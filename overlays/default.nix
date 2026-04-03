final: prev: {
  # ── Custom overlays ──────────────────────────────────
  # Override or extend nixpkgs packages here.
  comment-checker = final.callPackage ../pkgs/comment-checker { };
}
