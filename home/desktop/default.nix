# Linux 桌面的 home-manager 层：home/ 里唯一按「桌面角色」分出来的部分（其余 home/ 跨平台共享）。
# 只在 Linux 导入（见 home/default.nix）。DE 专属模块（plasma.nix，当前 DE = KDE Plasma 6，故引入
# plasma-manager）换 DE 时在这里换；跨 DE 的 fcitx5.nix 保留不动。
{ inputs, ... }:
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./plasma.nix
    ./fcitx5.nix
  ];
}
