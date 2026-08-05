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

    # 这台机器无硬件背光；软件 dim 会破坏 direct scanout，并触发 Chromium 窗口闪烁。
    # 因此只在 10 分钟后熄屏，不调暗或休眠。
    powerdevil.AC = lib.mkIf awesomePc {
      autoSuspend.action = "nothing";
      turnOffDisplay.idleTimeout = 600;
      dimDisplay.enable = false;
    };

    kscreenlocker = lib.mkIf awesomePc {
      autoLock = false;
      lockOnResume = false;
    };
  };

  # catppuccin/nix 无 Konsole port；直接挂路径，避开 customColorSchemes 解析 bug。
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
