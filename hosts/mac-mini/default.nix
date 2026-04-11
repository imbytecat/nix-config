{ ... }:

{
  # ── Mac Mini specific ─────────────────────────────────
  # Always plugged in — 24/7 server role

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Never sleep ─────────────────────────────────────
  power.sleep.computer = 0;
  power.sleep.display = 0;
  power.sleep.harddisk = 0;
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  system.stateVersion = 5;
}
