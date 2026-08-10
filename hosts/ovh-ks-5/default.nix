{ pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    # 美国到中国的直连 TCP；其余调优需指标证据。
    kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";
  };

  environment.systemPackages = [ pkgs.neovim ];

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
}
