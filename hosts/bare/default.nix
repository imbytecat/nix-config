{ username, ... }:

{
  # ── Boot ─────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Network ──────────────────────────────────────────
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # ── Hardware ─────────────────────────────────────────
  # After first install, generate and uncomment:
  #   sudo nixos-generate-config --show-hardware-config > hosts/bare/hardware-configuration.nix
  # imports = [ ./hardware-configuration.nix ];

  system.stateVersion = "24.11";
}
