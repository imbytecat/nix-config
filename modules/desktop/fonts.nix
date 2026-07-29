# NixOS 桌面显示字体 —— 与跨平台编码字 modules/shared/fonts.nix 分家：fonts.fontconfig
# 是 NixOS 专有选项，写进 shared 会让两台 mac 的 eval 报错；mac 也自带 PingFang/emoji 无需这些。
# 下面 mkBefore 把 SC 字族摆到 defaultFonts 最前：否则 defaultLocale=en_US 会让统一汉字落到日文字形。
{ pkgs, lib, ... }:

let
  # 真 Windows 10 字体（宋体/黑体/楷体/仿宋/微软雅黑/等线 + Calibri/Times New Roman 等），
  # 让 WPS 打开别人发来的文档能按具名字体渲染、不串版；具体两个上游与取舍见 pkgs/ttf-ms-win10。
  ttf-ms-win10 = pkgs.callPackage ../../pkgs/ttf-ms-win10 { };
in
{
  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic
      lxgw-wenkai
      inter
      ttf-ms-win10
    ];

    # 用 mkBefore 把首选字族插到 Plasma 6 默认(Noto Sans/Serif、Hack)之前：
    # 既保证顺序确定，又保留 Plasma 的值作为尾部兜底。CJK 一律钉 SC 字形。
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
