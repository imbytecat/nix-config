{ lib, username, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "26.05";

  # 只有 root 是 RAID0，坏任一块盘即整机重装；ESP 与 /boot 仍是 RAID1，固件从哪块盘都能引导。
  disko.devices.mdadm.root.level = 0;

  networking.useDHCP = true;
  services.tailscale.openFirewall = true;

  home-manager.users.${username}.programs.t3code.server.extraArgs = lib.mkBefore [
    "--host"
    "127.0.0.1"
  ];
}
