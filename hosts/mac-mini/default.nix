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

  # 前置：关 FileVault + 首次手动在系统设置里输一次密码生成 /etc/kcpassword
  # （nix-darwin 只写 loginwindow plist 的 autoLoginUser key，不会写 kcpassword）
  system.defaults.loginwindow.autoLoginUser = username;
  system.defaults.loginwindow.GuestEnabled = false;
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  # Screen Sharing 自 macOS 12.1 起无法用 launchctl/kickstart 完整启用，
  # 需手动在 System Settings → 通用 → 共享 里打开。
  system.activationScripts.postActivation.text = ''
    pmset -a autorestart 1
    pmset -a autopoweroff 0
    pmset -a standby 0
    pmset -a ttyskeepawake 1
  '';

  system.stateVersion = 6;
}
