# NixOS 桌面字体；SC 字族需排在默认 Noto 前，避免 en_US 选到日文字形。
{ pkgs, lib, ... }:

{
  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic
      lxgw-wenkai
      inter
      ttf-ms-win10 # WPS 需要 Windows 具名字体；来源取舍见 pkgs/ttf-ms-win10。
    ];

    fontconfig.defaultFonts = {
      sansSerif = lib.mkBefore [
        "Inter"
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      serif = lib.mkBefore [
        "Noto Serif"
        "Noto Serif CJK SC"
      ];
      monospace = lib.mkBefore [
        "Maple Mono NF CN"
        "Sarasa Mono SC"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
