# KDE Plasma 6 的 home 设置（plasma-manager）。仅当系统启用 Plasma 6 时生效（osConfig 跟随
# modules/desktop/nixos.nix）。把 fcitx5 注册为 KWin Wayland 虚拟键盘（input-method-v2，补
# XWayland/旧程序），与 waylandFrontend 互补、二者都要，详见 docs/adr/0003-wayland-ime-fcitx.md。
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

  # Konsole 声明式外观：字体钉 Maple Mono NF CN（与 modules/desktop/fonts.nix monospace 首选一致），
  # 配色挂 Catppuccin Mocha —— catppuccin/nix 无 konsole port，autoEnable 漏掉它，故手动挂官方
  # colorscheme（flake input catppuccin-konsole），不再是默认 Breeze。
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
      };
    };
  };
}
