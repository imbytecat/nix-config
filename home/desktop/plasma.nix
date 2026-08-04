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

    # awesome-pc 保持后台任务常驻，只熄屏（10 分钟，与之前的 Plasma 默认一致）。
    # dimDisplay 要显式关：默认 AC 5 分钟先调暗到 30%，而这台机器无背光、无 /dev/i2c-*
    # （无 DDC/CI），调暗只能走 KWin 软件亮度乘子 → 输出 color pipeline 非 identity；
    # amdgpu 上 KWin 默认不开 KMS color pipeline 卸载，于是 direct scanout 被拒、整屏
    # 改走 GPU 合成，唤醒再切回来 —— 这一来一回是 Brave 等 Chromium 窗口偶发闪烁的触发点。
    powerdevil.AC = lib.mkIf awesomePc {
      autoSuspend.action = "nothing";
      turnOffDisplay.idleTimeout = 600;
      dimDisplay.enable = false;
    };

    # 只熄屏不锁屏：熄屏由 powerdevil 负责，kscreenlocker 的自动锁屏这一路单独关掉，
    # 否则默认 5 分钟会在熄屏前先锁上。
    kscreenlocker = lib.mkIf awesomePc {
      autoLock = false;
      lockOnResume = false;
    };
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
