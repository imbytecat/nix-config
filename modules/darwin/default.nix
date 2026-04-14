{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  system.primaryUser = username;

  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
    uid = 501;
    openssh.authorizedKeys.keys = sshKeys;
  };

  # ── macOS system preferences ───────────────────────
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
      # Suppress donation prompt permanently (date far in the future)
      "donate.reminder.date" = 253402300799000;
    };
  };

  # ── Homebrew ───────────────────────────────────────
  homebrew = {
    enable = true;
    greedyCasks = true; # always upgrade casks even if they auto-update

    taps = [
      "goooler/repo"
    ];

    brews = [
      "mole"
    ];

    # GUI apps
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
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Windows App" = 1295203466;
      "Xnip" = 1221250572;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap"; # remove anything not declared above
    };
  };
}
