{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    # Darwin 用 Homebrew cask（modules/desktop/darwin.nix）；Linux 交给 HM，systemd/D-Bus 集成需要 package。
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 14;
      shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
    };
  };
}
