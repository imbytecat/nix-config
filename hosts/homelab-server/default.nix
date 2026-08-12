{
  imports = [
    ../../modules/nixos/qemu-guest.nix
    ./disko.nix
  ];

  system.stateVersion = "25.11";

  networking.useDHCP = true;
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;
}
