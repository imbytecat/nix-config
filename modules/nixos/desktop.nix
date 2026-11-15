{
  aspects.nixos.desktop =
    { inputs, username, ... }:
    {
      # 不提供 X11 session；XWayland 由 Plasma 自带。
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      services.desktopManager.plasma6.enable = true;
      hardware.graphics.enable = true;

      networking.networkmanager.enable = true;
      # 禁用会探测并抢占 /dev/ttyUSB* 的 ModemManager。
      networking.modemmanager.enable = false;
      users.users.${username}.extraGroups = [
        "networkmanager"
        "dialout"
      ];

      services.printing.enable = true;

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      # binfmt 让 ./xxx.AppImage 直接执行（单开 binfmt 无效，被 enable 门控）。
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      # Solaar 支持该鼠标；libratbag 不支持，故不装 piper。
      programs.solaar.enable = true;

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      home-manager.users.${username} = {
        imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

        programs.plasma = {
          enable = true;
          configFile.kwinrc.Wayland.EnablePrimarySelection = false;
        };

        # catppuccin/nix 无 Konsole port；直接挂路径，避开 customColorSchemes 解析 bug。
        xdg.dataFile."konsole/Catppuccin-Mocha.colorscheme".source =
          inputs.catppuccin-konsole + "/themes/catppuccin-mocha.colorscheme";

        programs.konsole = {
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
      };
    };
}
