{ lib, ... }:

{
  # 首装前按目标磁盘覆盖。
  disko.devices.disk.main.device = lib.mkDefault "/dev/sda";

  nix.settings.substituters = lib.mkBefore [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];

  system.stateVersion = "26.05";
}
