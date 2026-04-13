{
  inputs,
  lib,
  username,
  pkgs,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
    ./theme.nix
  ];

  home = {
    username = username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "24.11";
  };

  # ── User-level packages ────────────────────────────
  home.packages =
    with pkgs;
    [
      # Modern CLI replacements
      dust # du
      duf # df
      procs # ps
      sd # sed
      xh # curl/httpie
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

      # Secrets management (WSL uses Windows op.exe via interop)
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      _1password-cli
    ]
    ++ (with pkgs; [
      # AI coding agent
      opencode
      comment-checker

      # Misc
      ffmpeg
      pandoc
    ]);

  # XDG directories
  xdg.enable = true;
}
