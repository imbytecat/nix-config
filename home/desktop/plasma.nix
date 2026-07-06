# KDE Plasma 6 的 home 设置（plasma-manager）。仅当系统实际启用 Plasma 6 时生效 ——
# osConfig 跟随 modules/desktop/nixos.nix 的桌面角色，无头 Linux / 将来换 DE 时自动为空。
#
# 当前只声明一项：把 fcitx5 注册为 KWin 的 Wayland 虚拟键盘，等价于手动点
# 「系统设置 → 虚拟键盘 → Fcitx 5」，免得每次重装/重置后再点一遍。
# 落到 ~/.config/kwinrc 的 [Wayland] InputMethod（指向 fcitx5 的 wayland launcher desktop）。
# 与 modules/desktop/nixos.nix 的 waylandFrontend=true 互补、二者都要：
#   本项走 KWin input-method-v2（XWayland / 不支持 text-input 的旧程序）；
#   waylandFrontend 走 text-input-v3（原生 Wayland 程序）。
{ osConfig, lib, ... }:
{
  programs.plasma = lib.mkIf osConfig.services.desktopManager.plasma6.enable {
    enable = true;
    configFile.kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
  };
}
