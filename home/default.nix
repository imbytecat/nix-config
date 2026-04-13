{
  inputs,
  username,
  pkgs,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  home = {
    username = username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "24.11";
  };

  # ── User-level packages ────────────────────────────
  home.packages = with pkgs; [
    # Modern CLI replacements
    dust # du
    duf # df
    procs # ps
    sd # sed
    jq # JSON
    yq # YAML
    wget

    # System info
    fastfetch
    tealdeer # tldr

    # File management
    gomi

    # Nix tools
    nix-output-monitor # nom
    nvd # nix version diff
    nh # nix helper
    just

    # AI coding agent
    opencode
    comment-checker

    # Misc
    ffmpeg
    pandoc
  ];

  # XDG directories
  xdg.enable = true;
}
