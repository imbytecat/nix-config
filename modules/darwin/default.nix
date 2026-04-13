{ pkgs, username, ... }:

{
  # ── Primary user (required by nix-darwin) ──────────
  system.primaryUser = username;

  # ── Shell ──────────────────────────────────────────
  programs.fish.enable = true;

  # ── 1Password CLI ───────────────────────────────────
  programs._1password.enable = true;

  # ── SSH ───────────────────────────────────────────
  services.openssh.enable = true;

  # ── User ───────────────────────────────────────────
  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
    uid = 501;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
    ];
  };

  # ── Fonts ──────────────────────────────────────────
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
    nerd-fonts.symbols-only
  ];

  # ── macOS system preferences ───────────────────────
  system.defaults = {
    LaunchServices.LSQuarantine = false;
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
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
      "mole" # broken in nixpkgs
    ];

    # GUI apps
    casks = [
      "1password"
      "brave-browser"
      "cherry-studio"
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
