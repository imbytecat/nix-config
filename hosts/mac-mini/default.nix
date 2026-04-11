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

  # ── Screen Sharing (VNC) & pmset ─────────────────
  system.activationScripts.postActivation.text = ''
    # VNC
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    # Wake on LAN
    pmset -a womp 1
    # Disable Power Nap
    pmset -a powernap 0
  '';

  system.stateVersion = 5;
}
