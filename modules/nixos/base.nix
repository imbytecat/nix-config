# NixOS 基线：所有 NixOS 主机（无头服务器 / 无头开发 / 桌面）都成立的事实。
# 往上叠：./dev.nix（日用开发）→ modules/desktop/nixos.nix（GUI）；无头服务器叠 ./server.nix。
# 判据：只要有一种角色不需要，就不许放这里 —— 角色化的东西去 ./dev.nix / ./server.nix。
{
  imports = [
    ../shared/gc.nix
    ../shared/nix.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Asia/Shanghai";

  # 每台机器都要能 SSH 进去。硬化策略按角色分（见 ./server.nix），桌面沿用上游默认
  services.openssh.enable = true;

  # 所有 NixOS 主机都不休眠，统一用压缩内存兜底 OOM，不占磁盘 swap
  zramSwap.enable = true;

}
