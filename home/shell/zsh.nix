{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autocd = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git" # git aliases (gst, gco, gp...)
        "sudo" # double ESC → prepend sudo
        "extract" # x file.tar.gz → auto extract
        "direnv" # direnv hook
      ];
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # Navigation
      cd = "z";
      cdi = "zi";
      ".." = "cd ..";
      "..." = "cd ../..";

      # File listing (eza)
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --git --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lt = "eza --tree --level=2 --icons";

      # Tools
      cat = "bat --paging=never";
      rm = "trash-put";
      lg = "lazygit";
      vi = "nvim";

      # Network
      http = "xh";

      # Nix shortcuts
      rebuild = "sudo nixos-rebuild switch --flake ~/.config/nix-config";
      update = "nix flake update --flake ~/.config/nix-config";
    };

    initExtra = ''
      # ── Shell options ──
      setopt INTERACTIVE_COMMENTS
      setopt NO_BEEP

      # ── PATH (manual go/bun global tools) ──
      export PATH="$HOME/go/bin:$HOME/.bun/bin:$PATH"

      # ── fzf-tab plugin ──
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

      # ── mise ──
      eval "$(mise activate zsh)"

      # ── WSL clipboard ──
      if [[ -n "$WSL_DISTRO_NAME" ]]; then
        alias pbcopy="clip.exe"
        alias pbpaste="powershell.exe -noprofile -c Get-Clipboard"
      fi

      # ── User-local overrides ──
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };
}
