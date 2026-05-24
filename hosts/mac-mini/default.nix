{ ... }:

{
  # 桌面主力机：常开机以保证 SSH / Tailscale 远程可达。Apple Silicon Mac mini
  # 默认会进类休眠的"假关机"，下面 autopoweroff/standby 必须显式关掉。
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  networking.wakeOnLan.enable = true;

  system.defaults.loginwindow.GuestEnabled = false;

  system.activationScripts.postActivation.text = ''
    pmset -a autorestart 1
    pmset -a autopoweroff 0
    pmset -a standby 0
    pmset -a ttyskeepawake 1

    # 开定位 + 自动时区。改完要 kickstart locationd 才能立刻生效
    sudo -u _locationd defaults -currentHost write com.apple.locationd LocationServicesEnabled -bool true
    defaults write /Library/Preferences/com.apple.timezone.auto Active -bool true
    launchctl kickstart -k system/com.apple.locationd
  '';

  system.stateVersion = 6;
}
