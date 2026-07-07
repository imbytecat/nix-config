# KDE Plasma 6 的 home 设置（plasma-manager）。仅当系统实际启用 Plasma 6 时生效 ——
# osConfig 跟随 modules/desktop/nixos.nix 的桌面角色，无头 Linux / 将来换 DE 时自动为空。
#
# 当前只声明一项：把 fcitx5 注册为 KWin 的 Wayland 虚拟键盘，等价于手动点
# 「系统设置 → 虚拟键盘 → Fcitx 5」，免得每次重装/重置后再点一遍。
# 落到 ~/.config/kwinrc 的 [Wayland] InputMethod（指向 fcitx5 的 wayland launcher desktop）。
# 与 modules/desktop/nixos.nix 的 waylandFrontend=true 互补、二者都要：
#   本项走 KWin input-method-v2（XWayland / 不支持 text-input 的旧程序）；
#   waylandFrontend 走 text-input-v3（原生 Wayland 程序）。
{
  inputs,
  osConfig,
  lib,
  ...
}:
let
  plasmaEnabled = osConfig.services.desktopManager.plasma6.enable;
in
{
  programs.plasma = lib.mkIf plasmaEnabled {
    enable = true;
    configFile.kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
  };

  # Konsole 声明式外观（plasma-manager）—— 之前没配，字体/配色都吃 Konsole 内置默认，
  # 故显得「一般」。这里两件事对齐其余桌面：
  #   1. 字体钉 Maple Mono NF CN / 14，与 Ghostty(home/shell/ghostty.nix)、
  #      modules/desktop/fonts.nix 的 monospace 首选一致；
  #   2. 配色补 Catppuccin Mocha —— catppuccin/nix 无 konsole port，全局 autoEnable 唯独
  #      漏掉它，故手动挂官方 colorscheme(flake input catppuccin-konsole)，不再是默认 Breeze。
  # 落到 ~/.local/share/konsole/{Main.profile,Catppuccin-Mocha.colorscheme} + konsolerc 默认 profile。
  programs.konsole = lib.mkIf plasmaEnabled {
    enable = true;
    defaultProfile = "Main";
    customColorSchemes.Catppuccin-Mocha =
      inputs.catppuccin-konsole + "/themes/catppuccin-mocha.colorscheme";
    profiles.Main = {
      name = "Main";
      colorScheme = "Catppuccin-Mocha";
      font = {
        name = "Maple Mono NF CN";
        size = 14;
      };
    };
  };
}
