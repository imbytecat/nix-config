{
  imports = [ ./disko.nix ];

  system.stateVersion = "26.05";

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;
}
