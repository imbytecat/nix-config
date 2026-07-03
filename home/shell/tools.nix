{ config, pkgs, ... }:

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
    changeDirWidget.command = "fd --type d --hidden --follow --exclude .git";
    fileWidget.command = "fd --type f --hidden --follow --exclude .git";
    fileWidget.options = [
      "--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || eza -la {}'"
    ];
    # Ctrl-R 交给 Atuin：空字符串禁用 fzf 的 history widget 绑定
    historyWidget.command = "";
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
    options = [ "--cmd cd" ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      global = {
        warn_timeout = "120s";
      };
      whitelist = {
        prefix = [
          "${config.home.homeDirectory}/Developer"
          "${config.home.homeDirectory}/nix-config"
        ];
      };
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
