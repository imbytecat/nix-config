{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── CachyOS 内核（桌面响应性：EEVDF + 1000Hz + full preempt）──
  # pinned overlay 用该 flake 锁定的 nixpkgs revision 构建，命中 binary cache（attic.xuyh0120.win）。
  # 选非 LTO 变体（LTO 与 nvidia 等 out-of-tree 模块兼容性差）；感觉不到差异删这两行退默认内核。
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # ── GPU（硬件属性，与桌面角色解耦；换 Intel 卡时只改这一段）──
  # Wayland-only：不开 services.xserver.enable，videoDrivers 仅控制驱动加载
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    nvidiaPersistenced = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  system.stateVersion = "25.11";
}
