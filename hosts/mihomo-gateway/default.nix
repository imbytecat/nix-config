{
  lib,
  sshKeys,
  ...
}:

{
  imports = [
    ./disko.nix
  ];

  # 网关在国内网络，自己 rebuild 时走 SJTU；开发机/CI 因为本机构建 + SCP 推送，走默认 cache 即可
  nix.settings.substituters = lib.mkBefore [
    "https://mirror.sjtu.edu.cn/nix-channels/store"
  ];

  system.stateVersion = "25.11";
  # 不安装本地化数据，纯 ASCII，省空间
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  fonts.fontconfig.enable = false;
  time.timeZone = "Asia/Shanghai";

  # 物理机 / KVM 通用：systemd-boot + 常见 virtio 驱动
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # KVM/QEMU 目标需要；stock initrd 默认只有 ahci/nvme/sata，虚拟磁盘看不到导致 boot 后进 emergency
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];

  # 网关单用户 root，硬化 SSH：禁用密码、root 仅密钥
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
