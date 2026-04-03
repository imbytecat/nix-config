{
  inputs,
  username,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin
    ./shell
    ./dev
    ./theme.nix
  ];

  home = {
    username = username;
    homeDirectory =
      if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "24.11";
  };

  # ── User-level packages ────────────────────────────
  home.packages = with pkgs; [
    # Modern CLI replacements
    dust # du
    duf # df
    procs # ps
    sd # sed
    xh # curl/httpie
    jq # JSON
    yq # YAML

    # System info
    fastfetch
    tealdeer # tldr

    # File management
    trash-cli

    # Terminal multiplexer (alternative)
    zellij

    # Nix tools
    nix-output-monitor # nom — better nix build output
    nvd # nix version diff
    nh # nix helper (nixos-rebuild wrapper)

    # Misc
    micro # simple editor fallback
  ];

  # XDG directories
  xdg.enable = true;
}
