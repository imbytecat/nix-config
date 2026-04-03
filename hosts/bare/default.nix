{ config, pkgs, ... }:

let
  username = "dev"; # ← 修改此处设置用户名
in
{
  # ── 引导 ─────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── 网络 ─────────────────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # ── 用户 ─────────────────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  # ── Home Manager ─────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ../../home;
  };

  # ── sudo ─────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # ── 硬件 ─────────────────────────────────────────────
  # 首次安装后生成硬件配置并取消注释：
  #   sudo nixos-generate-config --show-hardware-config > hosts/bare/hardware-configuration.nix
  # imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "24.11";
}
