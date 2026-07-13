# 跨 DE 的 fcitx5/rime home 配置（换 GNOME/Hyprland/niri 也照用；与 plasma.nix 的 Plasma 专属
# KWin InputMethod 互补、二者都要，详见 docs/adr/0003-wayland-ime-fcitx.md）。按
# osConfig.i18n.inputMethod.enable 收窄——系统真开输入法才写，与 plasma.nix 同纪律，无头机不落多余 dotfile。
{
  lib,
  osConfig,
  config,
  pkgs,
  ...
}:

lib.mkIf osConfig.i18n.inputMethod.enable {
  # 雾凇拼音需用户侧 default.custom.yaml __include 才有候选（见 docs/adr/0003-wayland-ime-fcitx.md）。
  # 后续 Rime 自定义（按键、候选数等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    text = ''
      patch:
        __include: rime_ice_suggestion:/
        # 关掉 rime 内部 Shift 切 ascii_mode——中英状态只留 fcitx5 组切换（CapsLock）一个入口
        ascii_composer/switch_key/Shift_L: noop
    '';
    # librime 靠 mtime 判断是否需要重编译，而 nix store 文件 mtime 恒为 1970——patch 变了
    # rime 也认为"没变化"永远跳过重编译。onChange（内容比对、link 后执行）删 build/ 强制
    # 重编，再尽力触发在线部署；D-Bus 不可用（如系统激活时无会话）也无妨，fcitx5 下次启动自会重建。
    onChange = ''
      rm -rf "${config.xdg.dataHome}/fcitx5/rime/build"
      ${pkgs.systemd}/bin/busctl --user call org.fcitx.Fcitx5 /controller \
        org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/addon/rime/deploy" s "" || true
    '';
  };

  # fcitx5 输入法组：默认 IM=rime；home-manager 每 switch 覆盖 ~/.config/fcitx5/profile，新装即成型。
  # 为何走用户路径而非 NixOS ignoreUserConfig，见 docs/adr/0003-wayland-ime-fcitx.md。
  xdg.configFile."fcitx5/profile".text = lib.generators.toINI { } {
    GroupOrder."0" = "Default";
    "Groups/0" = {
      Name = "Default";
      "Default Layout" = "us";
      DefaultIM = "rime";
    };
    "Groups/0/Items/0".Name = "keyboard-us";
    "Groups/0/Items/1".Name = "rime";
  };

  # 触发键只绑 Hangul（CapsLock 经 keyd 重映射而来，见 modules/desktop/nixos.nix），
  # 显式覆盖默认的 Ctrl+Space——把它还给应用（VS Code 补全等）。文件被 HM 管成只读
  # symlink 后 fcitx5 GUI 改不了全局热键，与 profile 同纪律。
  xdg.configFile."fcitx5/config".text = lib.generators.toINI { } {
    "Hotkey/TriggerKeys"."0" = "Hangul";
    # fcitx5 自身默认 AltTriggerKeys=Shift_L（临时切换 IM），与 rime 内部 Shift 切换叠加；
    # 置空，杜绝单击 Shift 误切中英
    "Hotkey/AltTriggerKeys"."0" = "";
  };
}
