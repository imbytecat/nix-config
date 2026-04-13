{ username, ... }:

{
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
