{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  system.primaryUser = username;

  # ── 免密 sudo ────────────────────────────────────────
  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD:ALL
  '';

  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
    uid = 501;
    openssh.authorizedKeys.keys = sshKeys;
  };

  # ── macOS 系统偏好设置 ────────────────────────────────
  system.defaults = {
    LaunchServices.LSQuarantine = false;
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      show-recents = false;
      mru-spaces = false;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };
    finder.FXPreferredViewStyle = "clmv";
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    CustomUserPreferences."ch.sudo.cyberduck" = {
      # 永久禁用捐赠提示（日期设为遥远的未来）
      "donate.reminder.date" = 253402300799000;
    };
  };

  # ── Homebrew ───────────────────────────────────────
  homebrew = {
    enable = true;
    greedyCasks = true; # 即使 cask 自动更新也始终升级
    # 已废弃：Homebrew 将于 2026-09 后移除 --no-quarantine
    # 待所有 cask 通过 Gatekeeper（签名且公证）后移除此项
    caskArgs.no_quarantine = true;

    taps = [
      "goooler/repo"
    ];

    brews = [
      "mole"
    ];

    # GUI 应用
    casks = [
      "1password"
      "brave-browser"
      "cherry-studio"
      "cyberduck"
      "dbeaver-community"
      "discord"
      "feishu"
      "goooler/repo/fl-clash"
      "ghostty"
      "tailscale-app"
      "keka"
      "logitech-g-hub"
      "mos"
      "movist-pro"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "visual-studio-code"
      "wechat"
      "winbox"
    ];

    # Mac App Store
    masApps = {
      "iPreview" = 1519213509;
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Windows App" = 1295203466;
      "Xnip" = 1221250572;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap"; # 移除所有未声明的内容
    };
  };
}
