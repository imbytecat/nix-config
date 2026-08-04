{ pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    loader.grub.devices = [
      "/dev/nvme0n1"
      "/dev/nvme1n1"
    ];
    swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";
  };

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
}
