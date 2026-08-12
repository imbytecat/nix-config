{
  imports = [ ./disko.nix ];

  system.stateVersion = "25.11";

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  networking.useDHCP = true;
  services.qemuGuest.enable = true;
  virtualisation.docker.enable = true;
}
