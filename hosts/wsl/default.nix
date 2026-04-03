{ config, pkgs, ... }:

let
  username = "dev"; # ← 修改此处设置用户名
in
{
  # ── WSL ──────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = username;
  };

  networking.hostName = "nixos-wsl";

  # ── 用户 ─────────────────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  # ── Home Manager ─────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ../../home;
  };

  # ── sudo ─────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}
