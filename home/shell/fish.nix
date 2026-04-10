{ ... }:

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
      update = "nix flake update --flake ~/Developer/nix-config";
    };

    interactiveShellInit = ''
      # No greeting
      set -g fish_greeting

      # PATH
      fish_add_path $HOME/go/bin $HOME/.bun/bin

      # mise
      mise activate fish | source

      # Sudo: double Escape to prepend sudo
      bind \e\e 'fish_commandline_prepend sudo'

      # Platform-specific rebuild command (derive flake attr from hostname)
      if test (uname) = Darwin
        set -l attr (scutil --get LocalHostName | string lower | string replace 'awesome-' "")
        abbr --add rebuild "sudo darwin-rebuild switch --flake ~/Developer/nix-config#$attr"
      else
        abbr --add rebuild "sudo nixos-rebuild switch --flake ~/Developer/nix-config#wsl"
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
