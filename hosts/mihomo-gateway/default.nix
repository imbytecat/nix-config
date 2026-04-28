{
  lib,
  sshKeys,
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
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  fonts.fontconfig.enable = false;
  time.timeZone = "Asia/Shanghai";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # KVM/QEMU：stock initrd 没 virtio，虚拟磁盘看不到会进 emergency
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  services.qemuGuest.enable = true;

  # root-only 硬化 SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = sshKeys;
  };
}
