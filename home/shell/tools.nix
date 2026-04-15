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

  # ── Atuin（Shell 历史记录）─────────────────────────────
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

  # ── Zoxide（智能 cd）──────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ]; # 用 cd/cdi 替代 z/zi
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

  # ── Bat（cat 替代）────────────────────────────────────
  programs.bat = {
    enable = true;
    extraPackages = with pkgs.bat-extras; [
      batgrep
      batwatch
    ];
  };

  # ── Eza（ls 替代）─────────────────────────────────────
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
    ];
  };

  # ── Yazi（文件管理器）────────────────────────────────
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";
  };

  # ── Btop（系统监控）──────────────────────────────────
  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
    };
  };

  # ── Zellij（终端复用器）──────────────────────────────
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
