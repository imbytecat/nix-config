{ ... }:

{
  # ── Mac Mini 专属配置 ────────────────────────────────
  # 常驻供电 — 全天候服务器角色

  # Touch ID 验证 sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── 禁止睡眠 ────────────────────────────────────────
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  # ── 网络唤醒（WoL）─────────────────────────────────
  networking.wakeOnLan.enable = true;

  # ── 屏幕共享（VNC）& pmset ──────────────────────────
  system.activationScripts.postActivation.text = ''
    # VNC
    launchctl enable system/com.apple.screensharing
    launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
    # 禁用 Power Nap
    pmset -a powernap 0
  '';

  system.stateVersion = 5;
}
