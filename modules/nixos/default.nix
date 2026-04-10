{ pkgs, username, ... }:

{
  imports = [
    ./base.nix
    ./docker.nix
    ./locale.nix
  ];

  # ── Default shell ──────────────────────────────────
  programs.fish.enable = true;

  # ── Default user ───────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };

  # ── sudo ───────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;
}
