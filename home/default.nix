{ config, pkgs, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
  ];

  home.stateVersion = "24.11";

  # ── mise 配置 ──
  xdg.configFile."mise/config.toml".text = ''
    [settings]
    trusted_config_paths = ["/"]
  '';
}
