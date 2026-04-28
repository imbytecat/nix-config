{ ... }:

{
  # 全天候服务器角色，永不睡眠
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  networking.wakeOnLan.enable = true;

  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    pmset -a powernap 0
  '';

  system.stateVersion = 6;
}
