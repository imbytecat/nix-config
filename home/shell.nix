{ config, pkgs, ... }:

{
  # ── Zsh ──────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autocd = true; # setopt AUTO_CD

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git" # git 别名 (gst, gco, gp...)
        "sudo" # 双击 ESC 自动加 sudo
        "extract" # x file.tar.gz 一键解压
        "direnv" # direnv hook
      ];
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # 导航
      cd = "z";
      cdi = "zi";
      ".." = "cd ..";
      "..." = "cd ../..";

      # 文件列表
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --git --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lt = "eza --tree --level=2 --icons";

      # 工具
      cat = "bat --paging=never";
      rm = "trash-put";
      lg = "lazygit";
      vi = "nvim";

      # 网络
      http = "xh";
    };

    initExtra = ''
      # ── Shell 选项 ──
      setopt INTERACTIVE_COMMENTS
      setopt NO_BEEP

      # ── PATH（手动安装的 go/bun 全局工具）──
      export PATH="$HOME/go/bin:$HOME/.bun/bin:$PATH"

      # ── fzf-tab 插件 ──
      # 路径如有误，运行: ls $(nix eval --raw nixpkgs#zsh-fzf-tab)/share/
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

      # ── mise ──
      eval "$(mise activate zsh)"

      # ── WSL 剪贴板 ──
      if [[ -n "$WSL_DISTRO_NAME" ]]; then
        alias pbcopy="clip.exe"
        alias pbpaste="powershell.exe -noprofile -c Get-Clipboard"
      fi

      # ── 用户本地覆盖 ──
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };

  # ── Starship 提示符 ──────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$username$hostname$directory$git_branch$git_status$nodejs$python$go$rust$cmd_duration$line_break$character";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch.symbol = " ";

      git_status.format = "([\\[$all_status$ahead_behind\\]]($style) )";

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };

      nodejs = {
        format = "[$symbol($version)]($style) ";
        detect_extensions = [ ];
      };

      python.format = "[$symbol($version)]($style) ";
      go.format = "[$symbol($version)]($style) ";
    };
  };

  # ── FZF ──────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Atuin（历史搜索，接管 Ctrl+R）──────────────────
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Zoxide（智能 cd）─────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Direnv ───────────────────────────────────────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true; # 更好的 Nix devShell 集成
  };

  # ── Bat ──────────────────────────────────────────────
  programs.bat.enable = true;

  # ── Yazi ─────────────────────────────────────────────
  programs.yazi.enable = true;
}
