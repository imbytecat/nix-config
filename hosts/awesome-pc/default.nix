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

  # ── CachyOS 内核（桌面响应性：EEVDF 调优 + 1000Hz + full preempt）──
  # pinned overlay：用该 flake 锁定的 nixpkgs revision 构建内核，保证命中
  # binary cache（attic.xuyh0120.win，key 见 flake.nix nixConfig）。
  # 选非 LTO 变体：LTO 与部分 out-of-tree 模块（nvidia）兼容性差，作者建议
  # 出问题退回非 LTO。感觉不到桌面差异就删掉这两行退回默认内核。
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
