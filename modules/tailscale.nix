{
  # 服务器按需在 host 本地启用；网关刻意不进 tailnet。
  aspects.nixos.daily.services.tailscale.enable = true;
  aspects.darwin.desktop.homebrew.casks = [ "tailscale-app" ];
}
