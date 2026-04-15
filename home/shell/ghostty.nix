{ pkgs, ... }:

{
  programs.ghostty = {
    enable = pkgs.stdenv.isDarwin;
    package = null; # 通过 Homebrew cask 安装
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 14;
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
    };
  };
}
