{ pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";

  boot.swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";

  # Rakazo 的 install-images.sh 每次运行都检查 openssl（生成 .env 密钥）。
  environment.systemPackages = [ pkgs.openssl ];

  networking.useDHCP = true;

  # 公网只留 SSH 22 与 Tailscale 的 UDP 端口（便于直连）；Rakazo 只经 tailscale serve 进 tailnet。
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  virtualisation.docker = {
    enable = true;
    # 发布端口经 DNAT 走 FORWARD，绕过 NixOS 防火墙；没写宿主 IP 的端口一律只绑回环。
    daemon.settings.ip = "127.0.0.1";
  };
}
