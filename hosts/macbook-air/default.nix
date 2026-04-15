{ ... }:

{
  # ── MacBook Air 专属配置 ─────────────────────────────
  # 便携设备 — 注意电池续航

  # Touch ID 验证 sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # ── 刘海屏适配 ──────────────────────────────────────
  homebrew.casks = [
    "thaw" # 刘海屏菜单栏管理工具
  ];

  system.stateVersion = 5;
}
