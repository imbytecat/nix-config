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
    finder = {
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    screensaver = {
      # 屏保结束/解锁不要密码（即便意外进了屏保也不锁）
      askForPassword = false;
      askForPasswordDelay = 0;
    };
    CustomUserPreferences = {
      "ch.sudo.cyberduck" = {
        # 禁用捐赠提示（日期设为遥远的未来）
        "donate.reminder.date" = 253402300799000;
      };
      "com.apple.finder" = {
        WarnOnEmptyTrash = false;
      };
    };
  };

  # nix-darwin 的 system.defaults.screensaver.* 写的是用户全局 domain
  # (~/Library/Preferences/com.apple.screensaver.plist)，但 idleTime 在多数 macOS
  # 版本下实际读的是 per-host domain (ByHost/...)，所以这里用 -currentHost 兜底。
  # 写法对齐 nix-darwin 自己 system-defaults-write 的实现：launchctl asuser + sudo
  # --user=，确保 cfprefsd 在用户 launchd session 里看到改动。
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${username})" sudo --user=${username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0
  '';

  homebrew = {
    enable = true;
    enableFishIntegration = true;
    greedyCasks = true;

    taps = [
      "goooler/repo"
    ];

    brews = [
      "mole"
    ];

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
      "chromium"
      "tailscale-app"
      "keka"
      "logitech-g-hub"
      "mos"
      "movist-pro"
      "openscad@snapshot"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "uuremote"
      "visual-studio-code"
      "wechat"
      "winbox"
    ];

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
      cleanup = "zap"; # 移除未声明的 cask/brew
    };
  };
}
