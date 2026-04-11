{ ... }:

{
  # ── Mac Mini specific ─────────────────────────────────
  # Always plugged in — 24/7 server role

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── Never sleep ─────────────────────────────────────
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  system.stateVersion = 5;
}
