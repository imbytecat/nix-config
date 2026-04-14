{ ... }:

{
  # ── MacBook Air specific ──────────────────────────────
  # Portable — battery-conscious settings

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Notch-specific ─────────────────────────────────
  homebrew.casks = [
    "thaw" # menu bar manager for notched display
  ];

  system.stateVersion = 5;
}
