{ pkgs, username, ... }:

{
  # ── Shell ──────────────────────────────────────────
  programs.fish.enable = true;

  # ── User ───────────────────────────────────────────
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
  };

  # ── Fonts ──────────────────────────────────────────
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
    nerd-fonts.symbols-only
  ];

  # ── macOS system preferences ───────────────────────
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;
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

    taps = [
      "antoniorodr/memo"
      "steipete/tap"
    ];

    # CLI tools not in nixpkgs or needing brew services
    brews = [
      "ffmpeg"
      "gitui"
      "mas"
      "memo"
      "mole"
      "ollama"
      "pandoc"
      "poppler"
      "tailscale"
      "steipete/tap/gogcli"
      "steipete/tap/remindctl"
    ];

    # GUI apps
    casks = [
      "1password"
      "brave-browser"
      "cc-switch"
      "cherry-studio"
      "dbeaver-community"
      "discord"
      "feishu"
      "ghostty"
      "keka"
      "logitech-g-hub"
      "mos"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "telegram-desktop"
      "termius"
      "visual-studio-code"
      "wechat"
      "winbox"
    ];

    # Mac App Store
    masApps = {
      "Microsoft Word" = 462054704;
      "Windows App" = 1295203466;
      "Xnip" = 1221250572;
    };

    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; # remove anything not declared above
    };
  };
}
