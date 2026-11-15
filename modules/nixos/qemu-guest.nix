{
  # QEMU/VirtIO 虚拟机适配，VM 主机在 modules/hosts.nix 组合。
  aspects.nixos.qemu-guest = {
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "virtio_net"
    ];

    services.qemuGuest.enable = true;
  };
}
