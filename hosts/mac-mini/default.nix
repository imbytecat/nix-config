{ ... }:

{
  # ── Mac Mini specific ─────────────────────────────────
  # Always plugged in — desktop workstation role

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
