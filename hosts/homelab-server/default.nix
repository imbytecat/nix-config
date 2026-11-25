{ lib, ... }:

{
  # PVE 呈现的磁盘不是 /dev/sda 时，首装前改这里。
  disko.devices.disk.main.device = lib.mkDefault "/dev/sda";

  system.stateVersion = "26.05";

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;
}
