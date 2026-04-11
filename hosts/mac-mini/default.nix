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

  # ── Screen Sharing (VNC) ─────────────────────────
  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
  '';

  system.stateVersion = 5;
}
