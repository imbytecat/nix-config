{ username, ... }:

{
  # ── WSL ──────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = username;
  };

  system.stateVersion = "24.11";
}
