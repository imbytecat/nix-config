{ pkgs, lib, ... }:

{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      # Navigation
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

      # Nix
      update = "nix flake update --flake ~/.config/nix-config";
    };

    interactiveShellInit = ''
      # No greeting
      set -g fish_greeting

      # PATH
      fish_add_path $HOME/go/bin $HOME/.bun/bin

      # mise
      mise activate fish | source

      # Sudo: double Escape to prepend sudo (like zsh sudo plugin)
      bind \e\e 'fish_commandline_prepend sudo'

      # Platform-specific rebuild command
      if test (uname) = Darwin
        abbr --add rebuild "darwin-rebuild switch --flake ~/.config/nix-config"
      else
        abbr --add rebuild "sudo nixos-rebuild switch --flake ~/.config/nix-config"
      end

      # WSL clipboard
      if set -q WSL_DISTRO_NAME
        alias pbcopy clip.exe
        alias pbpaste "powershell.exe -noprofile -c Get-Clipboard"
      end

      # User-local overrides
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end
    '';
  };
}
