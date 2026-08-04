{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # pinned overlay 用该 flake 锁定的 nixpkgs revision 构建，命中 binary cache（attic.xuyh0120.win）。
  # 选非 LTO 变体；感觉不到差异删这两行退默认内核。
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # Wayland-only：不开 services.xserver.enable，videoDrivers 仅控制驱动加载
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.enableRedistributableFirmware = true;
  hardware.amdgpu.initrd.enable = true;

  environment.systemPackages = [ pkgs.nvtopPackages.amd ];

  # 桌面空闲时只允许息屏，系统始终保持运行；同时封住手动或应用触发的睡眠路径。
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

  system.stateVersion = "25.11";
}
