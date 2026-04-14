{ lib, username, ... }:

{
  # ── Shell ─────────────────────────────────────────────
  # Remove NixOS default aliases (ls/ll/l) — managed by Home Manager eza
  environment.shellAliases = lib.mkForce { };

  # ── WSL ──────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = username;
    interop.register = true;
  };

  # ── nix-ld (VSCode Remote, etc.) ────────────────────
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
