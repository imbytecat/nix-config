{ lib, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  boot = {
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        devices = [
          "/dev/nvme0n1"
          "/dev/nvme1n1"
        ];
        configurationLimit = 10;
      };
      efi = {
        canTouchEfiVariables = lib.mkForce false;
        efiSysMountPoint = "/boot";
      };
    };
    swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";
  };

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
}
