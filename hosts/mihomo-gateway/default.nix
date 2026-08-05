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

  # stock initrd 缺 virtio，KVM/QEMU 虚拟磁盘会不可见。
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  services.qemuGuest.enable = true;
}
