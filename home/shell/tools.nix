{ pkgs, ... }:

{
  programs.fzf = {
    enable = true;
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

  programs.atuin = {
    enable = true;
    settings = {
      enter_accept = true;
      filter_mode = "host";
      filter_mode_shell_up_key_binding = "session";
      style = "compact";
      inline_height = 20;
      show_help = false;
    };
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ]; # cd/cdi 替代 z/zi
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      warn_timeout = "120s";
    };
  };

  programs.bat = {
    enable = true;
    extraPackages = with pkgs.bat-extras; [
      batgrep
      batwatch
    ];
  };

  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
    ];
  };

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
    };
  };

  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      show_startup_tips = false;
    };
  };

  home.packages = with pkgs; [
    ripgrep
    fd
  ];
}
