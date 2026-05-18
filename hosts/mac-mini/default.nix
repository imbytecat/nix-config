{ username, ... }:

{
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  networking.wakeOnLan.enable = true;

  # 前置：关 FileVault；首次手动到系统设置输密码生成 /etc/kcpassword
  system.defaults.loginwindow.autoLoginUser = username;
  system.defaults.loginwindow.GuestEnabled = false;
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  system.activationScripts.postActivation.text = ''
    pmset -a autorestart 1
    pmset -a autopoweroff 0
    pmset -a standby 0
    pmset -a ttyskeepawake 1
  '';

  system.stateVersion = 6;
}
