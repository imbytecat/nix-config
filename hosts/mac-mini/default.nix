{ username, ... }:

{
  # mac-mini 当服务器/写代码机器，不导入 modules/darwin/daily.nix
  # （那 26 个日用 GUI cask 在这里都不需要）。下面只声明 server 实用 +
  # 远程控制兜底 + 本地写代码必须的工具。
  # onActivation.cleanup = "zap" 会把未声明的 cask 自动卸载。
  homebrew.casks = [
    "tailscale-app" # 服务器入口（被连端）
    "uuremote" # 主用远程桌面
    "1password" # 写代码要用密码/SSH key
    "ghostty" # 终端
    "visual-studio-code" # 本地写代码
    "orbstack" # 容器（轻量服务大概率涉及 Docker）
  ];

  # 全天候服务器角色，永不睡眠
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  networking.wakeOnLan.enable = true;

  # 开机自动登录：登录窗口里把本用户设为 auto-login。
  # ⚠️ 前置必须关闭 FileVault：Apple Silicon 加密盘要用户密码解锁才能进入
  #    loginwindow，开着 FileVault 时自动登录无法跨越冷启动/断电重启。
  # ⚠️ 首次启用后还要去 System Settings → Users & Groups → 自动登录
  #    选中本用户并输入一次密码，让系统生成 /etc/kcpassword。
  #    密码不放进 nix store，所以这一步只能手动做一次。
  system.defaults.loginwindow.autoLoginUser = username;
  system.defaults.loginwindow.GuestEnabled = false;

  # 服务器禁掉「下载好就装上重启」，避免半夜被强制重启断服务。
  # 仍可手动 `sudo softwareupdate -i -a` 更新。
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  system.activationScripts.postActivation.text = ''
    # 屏幕共享：VNC 远程
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true

    # pmset 强化（与 power.* 双保险，并补足 nix-darwin 没暴露的项）
    # autorestart=1   断电恢复后自动开机（来电自启）
    # womp=1          Wake on Magic Packet（配合 networking.wakeOnLan.enable）
    # powernap=0      禁用 Power Nap
    # autopoweroff=0  禁用深度休眠（Apple Silicon 默认 1，会让 mini "假关机"）
    # standby=0       禁用 standby
    # ttyskeepawake=1 SSH 活动保持系统唤醒
    pmset -a autorestart 1
    pmset -a womp 1
    pmset -a powernap 0
    pmset -a autopoweroff 0
    pmset -a standby 0
    pmset -a ttyskeepawake 1
  '';

  system.stateVersion = 6;
}
