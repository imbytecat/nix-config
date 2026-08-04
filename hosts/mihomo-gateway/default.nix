# 只放这台机器独有的事实：磁盘、虚拟化平台、镜像源、stateVersion。
# 无头服务器通用基线（SSH 硬化 / root-only / optimise / zram / 无 fontconfig）在
# modules/nixos/server.nix；GC 在 modules/shared/gc.nix，bootloader 显式组合，网关业务在 modules/gateway/。
{
  lib,
  ...
}:

{
  imports = [
    ./disko.nix
  ];

  nix.settings.substituters = lib.mkBefore [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];

  system.stateVersion = "25.11";

  # KVM/QEMU：stock initrd 没 virtio，虚拟磁盘看不到会进 emergency
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  services.qemuGuest.enable = true;
}
