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
  fonts.fontconfig.enable = false;
  time.timeZone = "Asia/Shanghai";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # ESP 只有 512M，generation 不设上限迟早塞满导致 switch 失败
  boot.loader.systemd-boot.configurationLimit = 10;
  # KVM/QEMU：stock initrd 没 virtio，虚拟磁盘看不到会进 emergency
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  services.qemuGuest.enable = true;

  # 无人值守长跑机：不回收 store 就是等着 31G 根分区被撑满
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  # 只有 2G 内存且没有 swap：mihomo 载入 1.5w 条规则 + geo 库时任何尖峰都会被 OOM killer
  # 直接干掉整个网关。zram 用压缩内存兜一层，不动磁盘。
  zramSwap.enable = true;

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
