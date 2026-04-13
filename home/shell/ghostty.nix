{ pkgs, ... }:

{
  programs.ghostty = {
    enable = pkgs.stdenv.isDarwin;
    package = null; # installed via Homebrew cask
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 14;
    };
  };
}
