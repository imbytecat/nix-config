# KDE Plasma 6 的 home 设置（plasma-manager）。仅当系统启用 Plasma 6 时生效（osConfig 跟随
# modules/desktop/nixos.nix）。把 fcitx5 注册为 KWin Wayland 虚拟键盘（input-method-v2，补
# XWayland/旧程序），与 waylandFrontend 互补、二者都要。
{
  inputs,
  osConfig,
  lib,
  ...
}:
let
  plasmaEnabled = osConfig.services.desktopManager.plasma6.enable;
  awesomePc = plasmaEnabled && osConfig.networking.hostName == "awesome-pc";
in
{
  programs.plasma = lib.mkIf plasmaEnabled {
    enable = true;
    configFile.kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";

    # awesome-pc 保持后台任务常驻；显示器仍按 Plasma 的既有 DPMS 时间自动熄灭。
    powerdevil.AC.autoSuspend.action = lib.mkIf awesomePc "nothing";
  };

  # Konsole 声明式外观：字体钉 Maple Mono NF CN（与 modules/desktop/fonts.nix monospace 首选一致），
  # 配色挂 Catppuccin Mocha —— catppuccin/nix 无 konsole port，autoEnable 漏掉它，故手动挂官方
  # colorscheme（flake input catppuccin-konsole），不再是默认 Breeze。
  # plasma-manager c551f 后 customColorSchemes 会把 flake input 拼出的 store path 字符串误当 INI attrset。
  xdg.dataFile."konsole/Catppuccin-Mocha.colorscheme" = lib.mkIf plasmaEnabled {
    source = inputs.catppuccin-konsole + "/themes/catppuccin-mocha.colorscheme";
  };

  programs.konsole = lib.mkIf plasmaEnabled {
    enable = true;
    defaultProfile = "Main";
    profiles.Main = {
      name = "Main";
      colorScheme = "Catppuccin-Mocha";
      font = {
        name = "Maple Mono NF CN";
      };
    };
  };
}
