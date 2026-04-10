{ ... }:

{
  # ── MacBook Air specific ──────────────────────────────
  # Portable — battery-conscious settings

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
