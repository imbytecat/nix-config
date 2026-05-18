{ username, ... }:

{
  homebrew.casks = [
    "tailscale-app"
    "uuremote"
    "1password"
    "ghostty"
    "visual-studio-code"
    "orbstack"
    # 暂留观察
    "chromium"
    "cyberduck"
    "keka"
    "mos"
    "raycast"
  ];

  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  networking.wakeOnLan.enable = true;

  # 前置：关 FileVault + 首次手动去系统设置输一次密码生成 /etc/kcpassword
  system.defaults.loginwindow.autoLoginUser = username;
  system.defaults.loginwindow.GuestEnabled = false;
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true

    pmset -a autorestart 1
    pmset -a womp 1
    pmset -a powernap 0
    pmset -a autopoweroff 0
    pmset -a standby 0
    pmset -a ttyskeepawake 1
  '';

  system.stateVersion = 6;
}
