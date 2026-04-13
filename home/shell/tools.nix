{ pkgs, ... }:

{
  # ── FZF ──────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
      "--info=inline"
    ];
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || eza -la {}'"
    ];
  };

  # ── Atuin (shell history) ────────────────────────────
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      enter_accept = true;
      filter_mode = "host";
      filter_mode_shell_up_key_binding = "host";
      style = "compact";
      inline_height = 20;
      show_help = false;
    };
  };

  # ── Zoxide (smart cd) ───────────────────────────────
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ]; # cd/cdi instead of z/zi
  };

  # ── Direnv + nix-direnv ─────────────────────────────
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true;
    config.global = {
      warn_timeout = "120s";
    };
  };

  # ── Bat (cat replacement) ───────────────────────────
  programs.bat = {
    enable = true;
    extraPackages = with pkgs.bat-extras; [
      batgrep
      batwatch
    ];
  };

  # ── Eza (ls replacement) ────────────────────────────
  programs.eza = {
    enable = true;
    enableFishIntegration = false; # we use custom abbrs in fish.nix
    git = true;
    icons = "auto";
    extraOptions = [
      "--color=always"
      "--group-directories-first"
    ];
  };

  # ── Yazi (file manager) ─────────────────────────────
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";
  };

  # ── Btop (system monitor) ───────────────────────────
  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
    };
  };

  # ── Zellij (terminal multiplexer) ────────────────────
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      show_startup_tips = false;
    };
  };

  # ── Ripgrep / FD ────────────────────────────────────
  home.packages = with pkgs; [
    ripgrep
    fd
  ];
}
