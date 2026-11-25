{ inputs, ... }:

let
  wowtypeFor = pkgs: inputs.wowtype.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # 每周依赖更新先构建它再自动合并，避免升级后才在本机编译失败。
  perSystem =
    { lib, pkgs, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux { wowtype = wowtypeFor pkgs; };
    };

  # 1 = CapsLock 切到 ABC，与 NixOS 上 CapsLock 单击切换中英一致。
  aspects.darwin.desktop.system.defaults.CustomUserPreferences.NSGlobalDomain.TISRomanSwitchState = 1;

  aspects.nixos.desktop =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          waylandFrontend = true;
          addons = [ (wowtypeFor pkgs) ];
        };
      };

      # CapsLock 单击触发 fcitx5，按住为 Ctrl，Shift+CapsLock 保留大写锁定。
      # 使用 Hangul，避免 F13 被 evdev 映射为 XF86Tools。
      services.keyd = {
        enable = true;
        keyboards.default = {
          ids = [ "*" ];
          settings = {
            main.capslock = "overload(control, hangeul)";
            shift.capslock = "capslock";
          };
        };
      };

      home-manager.users.${username} = {
        programs.plasma.configFile.kwinrc.Wayland.InputMethod =
          "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";

        xdg.configFile."fcitx5/profile".text = lib.generators.toINI { } {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "wowtype";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "wowtype";
        };

        # Hangul 由 CapsLock 映射触发；显式移除默认 Ctrl+Space。
        xdg.configFile."fcitx5/config".text = lib.generators.toINI { } {
          "Hotkey/TriggerKeys"."0" = "Hangul";
          # 禁用默认 Shift_L 临时切换，避免单击 Shift 误切中英
          "Hotkey/AltTriggerKeys"."0" = "";
        };

        # 设置界面用 os.replace 原子写，会把软链换成普通文件；下次 switch 按冲突直接替换收回，长期设置只写这里。
        # 开关只认 True/False 字符串，Nix 布尔值会被当成写错而回落默认。
        xdg.configFile."fcitx5/conf/wowtype.conf".text = lib.generators.toKeyValue { } {
          Shuangpin = "True";
          ShuangpinScheme = "Xiaohe";
          # 中英只由 CapsLock 切换，与上面禁用 Shift 临时切换一致。
          ShiftToggle = "Off";
          # 版本由 flake input 管理。
          CheckUpdate = "False";
        };
      };
    };
}
