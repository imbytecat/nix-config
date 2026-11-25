{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  # disko-install 不读这里的 device，以命令行 --disk main <path> 为准。
  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/disk/by-id/nvme-HS-SSD-C2000Pro_1024G_AA000000000000001070";
    content.partitions.ESP.size = "1G";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # 从默认 0xfff7bfff 仅清除 GFXOFF 位 0x8000，绕过 Navi 33 熄屏功耗异常（drm/amd#3549）。
  boot.kernelParams = [ "amdgpu.ppfeaturemask=0xfff73fff" ];

  # Wayland-only，不启用 X11 session。
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.enableRedistributableFirmware = true;
  hardware.amdgpu.initrd.enable = true;

  environment.systemPackages = [ pkgs.nvtopPackages.amd ];

  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  hardware.printers = {
    ensureDefaultPrinter = "Samsung_M2626D";
    ensurePrinters = [
      {
        name = "Samsung_M2626D";
        description = "Samsung M2626D";
        deviceUri = "ipp://10.24.1.1:631/printers/Samsung_M2626D";
        model = "everywhere";
      }
    ];
  };

  # 这台机器无硬件背光；软件 dim 会破坏 direct scanout，并触发 Chromium 窗口闪烁。
  # 因此只在 10 分钟后熄屏，不调暗或休眠。
  home-manager.users.${username}.programs.plasma = {
    powerdevil.AC = {
      autoSuspend.action = "nothing";
      turnOffDisplay.idleTimeout = 600;
      dimDisplay.enable = false;
    };

    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
    };
  };

  system.stateVersion = "26.05";
}
