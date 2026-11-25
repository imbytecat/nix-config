{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";

  boot.swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";

  networking.useDHCP = true;
  services.tailscale.openFirewall = true;

  home-manager.users.${username}.programs.t3code.server.extraArgs = lib.mkBefore [
    "--host"
    "127.0.0.1"
  ];
}
