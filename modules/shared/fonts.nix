# 跨平台编码字体（mac + NixOS 全平台一致，SSH 到任一日用机终端/编辑器观感相同）。
# 桌面显示字体（CJK 正文、emoji、UI/阅读字体 + fontconfig 调优）是 NixOS 专属，
# 见 modules/desktop/fonts.nix —— fonts.fontconfig 在 nix-darwin 上不存在，故分家。
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted # 主力编码字：等宽 + 连字 + 中文 + Nerd 图标
    nerd-fonts.symbols-only # 仅图标，给其它字体补 Nerd 符号兜底
  ];
}
