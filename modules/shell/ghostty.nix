{
  # 日用机终端是 Ghostty；SSH 到任何一台 NixOS 都要认识它的 TERM。
  aspects.nixos.base =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.ghostty.terminfo ];
    };

  aspects.darwin.desktop.homebrew.casks = [ "ghostty" ];

  aspects.homeManager.desktop =
    { pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        # Darwin 由上面的 cask 安装；Linux 交给 HM，它的 systemd/D-Bus 集成需要 package。
        package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;
        settings = {
          font-family = "Maple Mono NF CN";
          font-size = 14;
          shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
        };
      };
    };
}
