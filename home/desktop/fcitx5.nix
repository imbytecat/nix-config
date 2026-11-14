{
  lib,
  osConfig,
  ...
}:

lib.mkIf osConfig.i18n.inputMethod.enable {
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

  # 设置界面用 os.replace 原子写，会把软链换成普通文件；force 让 switch 收回，长期设置只写这里。
  xdg.configFile."fcitx5/conf/wowtype.conf" = {
    force = true;
    # 开关只认 True/False 字符串，Nix 布尔值会被当成写错而回落默认。
    text = lib.generators.toKeyValue { } {
      Shuangpin = "True";
      ShuangpinScheme = "Xiaohe";
      # 中英只由 CapsLock 切换，与上面禁用 Shift 临时切换一致。
      ShiftToggle = "Off";
      # 版本由 flake input 管理。
      CheckUpdate = "False";
    };
  };
}
