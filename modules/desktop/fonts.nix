# NixOS 桌面显示字体 —— 仅本文件在 NixOS 桌面(awesome-pc)生效，与跨平台编码字
# modules/shared/fonts.nix 分家：fonts.fontconfig 是 NixOS 专有选项，写进 shared
# 会让两台 mac 的 eval 直接报错；且 mac 自带 PingFang/Apple Emoji，无需这些。
#
# 背景：Plasma 6 只自动装 noto-fonts(无 CJK/emoji) + hack-font，而
# fonts.enableDefaultPackages 默认关，故此前中文仅靠 Maple Mono NF-CN 兜底、
# emoji 完全缺失(豆腐块)。另 modules/nixos 的 defaultLocale=en_US 会让统一汉字
# 优先落到日文字形，故下面用 mkBefore 把 SC 字族显式摆到 defaultFonts 最前。
{ pkgs, lib, ... }:

let
  # 真 Windows 10 字体（宋体/黑体/楷体/仿宋/微软雅黑/等线 + Calibri/Times New Roman 等），
  # 让 WPS 打开别人发来的文档能按具名字体渲染、不串版；具体两个上游与取舍见 pkgs/ttf-ms-win10。
  ttf-ms-win10 = pkgs.callPackage ../../pkgs/ttf-ms-win10 { };
in
{
  fonts = {
    packages = with pkgs; [
      # ── CJK 正文/界面 ──
      noto-fonts-cjk-sans # 思源黑体 (Noto Sans CJK)
      noto-fonts-cjk-serif # 思源宋体 (Noto Serif CJK)
      # ── 彩色 emoji ──
      noto-fonts-color-emoji
      # ── 中英混排等宽：更纱黑体，CJK 与西文 2:1 对齐，编辑器/终端排版利器 ──
      sarasa-gothic
      # ── 中文阅读/文档：霞鹜文楷，温润楷体风 ──
      lxgw-wenkai
      # ── 西文 UI sans ──
      inter
      # ── WPS/Office 文档保真：真 Windows 中文/西文具名字体 ──
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
