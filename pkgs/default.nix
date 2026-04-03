{ pkgs }:

{
  # ── Custom packages ──────────────────────────────────
  # Packages not in nixpkgs. Build with callPackage.
  #
  # Example:
  # opencode-ai = pkgs.callPackage ./opencode-ai { };
  #
  # go-comment-checker = pkgs.buildGoModule {
  #   pname = "comment-checker";
  #   version = "0.1.0";
  #   src = pkgs.fetchFromGitHub {
  #     owner = "code-yeongyu";
  #     repo = "go-claude-code-comment-checker";
  #     rev = "...";
  #     hash = "sha256-...";
  #   };
  #   vendorHash = "sha256-...";
  # };
}
