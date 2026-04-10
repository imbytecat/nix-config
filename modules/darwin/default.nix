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

  # ── Homebrew (GUI apps not in nixpkgs) ─────────────
  homebrew = {
    enable = true;
    casks = [
      "raycast"
      "arc"
    ];
    onActivation.cleanup = "zap";
  };
}
