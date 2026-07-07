# 跨 DE 的 fcitx5/rime home 配置（换 GNOME/Hyprland/niri 也照用；与 plasma.nix 的 Plasma 专属
# KWin InputMethod 互补、二者都要，详见 docs/adr/0003-wayland-ime-fcitx.md）。按
# osConfig.i18n.inputMethod.enable 收窄——系统真开输入法才写，与 plasma.nix 同纪律，无头机不落多余 dotfile。
{
  lib,
  osConfig,
  ...
}:

lib.mkIf osConfig.i18n.inputMethod.enable {
  # 雾凇拼音需用户侧 default.custom.yaml __include 才有候选（见 docs/adr/0003-wayland-ime-fcitx.md）。
  # 后续 Rime 自定义（按键、候选数等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      __include: rime_ice_suggestion:/
  '';

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
}
