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

  # pinned overlay 命中其 CachyOS 缓存；使用非 LTO 变体。
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

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

  system.stateVersion = "25.11";
}
