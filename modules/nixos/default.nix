{ pkgs, username, ... }:

{
  imports = [
    ./base.nix
    ./docker.nix
    ./locale.nix
  ];

  # ── Default shell ──────────────────────────────────
  programs.zsh.enable = true;

  # ── Default user ───────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  # ── sudo ───────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;
}
