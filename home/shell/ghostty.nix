{ pkgs, ... }:

{
  programs.ghostty = {
    enable = pkgs.stdenv.isDarwin;
    package = null; # 用 Homebrew cask
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 14;
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
    };
  };
}
