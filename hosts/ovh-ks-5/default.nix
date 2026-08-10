{ pkgs, ... }:

{
  imports = [
    ./backup.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    kernel.sysctl = {
      # 美国到中国的直连 TCP。
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # 默认 200 MiB/s 实测卡满；只抬上限，保留最低速率让繁忙时自动降速。
      "dev.raid.speed_limit_max" = 1000000;
    };

    swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";
  };

  # zstd 供手工回放 .dumps 里的 pg_dumpall 产物
  environment.systemPackages = [
    pkgs.neovim
    pkgs.zstd
  ];

  services.smartd.enable = true;
  services.openssh.ports = [ 22222 ];

  # mdadm 自带月度 scrub timer，但 NixOS 默认只链接单元，不会启动。
  systemd.targets.timers.wants = [ "mdcheck_start.timer" ];

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
}
