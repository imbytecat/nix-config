{ pkgs, username, ... }:

{
  imports = [
    ./base.nix
    ./docker.nix
    ./locale.nix
  ];

  # ── Default shell ──────────────────────────────────
  programs.fish.enable = true;

  # ── SSH ──────────────────────────────────────────
  services.openssh.enable = true;

  # ── Default user ───────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
    ];
  };

  # ── sudo ───────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;
}
