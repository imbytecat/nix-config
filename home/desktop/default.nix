# Linux 桌面的 home-manager 层：home/ 里唯一按「桌面角色」分出来的部分（其余 home/ 跨平台共享）。
# 只在 Linux 导入（见 home/default.nix）。当前 DE = KDE Plasma 6，故引入 plasma-manager；
# 将来换 DE（GNOME / Hyprland / niri…）只需在这里换导入，不动 home/default.nix。
{ inputs, ... }:
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    ./plasma.nix
  ];
}
