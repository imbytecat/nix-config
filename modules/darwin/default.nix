{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  system.primaryUser = username;

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD:ALL
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;

  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
    uid = 501;
    openssh.authorizedKeys.keys = sshKeys;
  };

  system.defaults = {
    LaunchServices.LSQuarantine = false;
    dock = {
      autohide = false;
      show-recents = false;
      mru-spaces = false;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };
    finder = {
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    screensaver = {
      askForPassword = false;
      askForPasswordDelay = 0;
    };
    CustomUserPreferences = {
      "ch.sudo.cyberduck" = {
        "donate.reminder.date" = 253402300799000; # 极远的未来
      };
      "com.apple.finder" = {
        WarnOnEmptyTrash = false;
      };
      # CapsLock 切换中英输入法（0=切换大小写，1=切到 ABC）
      "NSGlobalDomain" = {
        TISRomanSwitchState = 1;
      };
      # Raycast 接管 ⌘Space（下面 activation 会把 Spotlight 那两个快捷键关掉）
      "com.raycast.macos".raycastGlobalHotkey = "Command-49";
    };
  };

  # screensaver.idleTime 只读 per-host domain，用 -currentHost 兜底
  system.activationScripts.postActivation.text = ''
    user_uid="$(id -u -- ${username})"

    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0

    # 关 Spotlight 两个快捷键：64=⌘Space (Spotlight)、65=⌥⌘Space (Finder 搜索窗口)。
    # 必须 -dict-add 改单个 key，整体写会覆盖系统默认的几百条快捷键映射。
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '<dict><key>enabled</key><false/></dict>'
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '<dict><key>enabled</key><false/></dict>'
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  homebrew = {
    enable = true;
    enableFishIntegration = true;
    greedyCasks = true;

    taps = [
      "goooler/repo"
      "imbytecat/tap"
    ];

    brews = [
      "mole" # macOS 清理工具
    ];

    casks = [
      "1password"
      "brave-browser"
      "cherry-studio"
      "cyberduck"
      "dbeaver-community"
      "discord"
      "feishu"
      "ghostty"
      "goooler/repo/fl-clash"
      "imbytecat/tap/doubao-ime"
      "imbytecat/tap/roxy-browser"
      "imbytecat/tap/ugreen-nas"
      "keka"
      "logitech-g-hub"
      "microsoft-excel"
      "microsoft-powerpoint"
      "microsoft-word"
      "moonlight"
      "mos"
      "movist-pro"
      "openscad@snapshot"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "tailscale-app"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "ungoogled-chromium"
      "uuremote"
      "visual-studio-code"
      "wechat"
      "wechatwork"
      "windows-app"
      "winbox"
    ];

    masApps = {
      "iPreview" = 1519213509;
      "Xnip" = 1221250572;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      # Homebrew 5.1+ 要求 `brew bundle install --cleanup` 显式带 --force / --force-cleanup / $HOMEBREW_ASK
      extraFlags = [ "--force" ];
    };
  };
}
