{ ... }:

{
  # ── 1Password env template ──────────────────────────
  # op:// references only — no real secrets, safe to commit
  xdg.configFile."op/env.tpl".text = ''
    AI_GATEWAY_BASE_URL={{ op://Private/AI Gateway API/URL }}
    AI_GATEWAY_API_KEY={{ op://Private/AI Gateway API/凭据 }}
    EXA_API_KEY={{ op://Private/Exa API/凭据 }}
    CONTEXT7_API_KEY={{ op://Private/Context7 API/凭据 }}
  '';

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
      rm = "gomi";
      lg = "lazygit";
      vi = "nvim";

      # Network
      http = "xh";

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

      # WSL clipboard
      if set -q WSL_DISTRO_NAME
        alias pbcopy clip.exe
        alias pbpaste "powershell.exe -noprofile -c Get-Clipboard"
        alias op op.exe
      end

      # User-local overrides
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end

      # 1Password → env vars (single op call, silent if locked)
      if type -q op; and test -f ~/.config/op/env.tpl
        for line in (op inject < ~/.config/op/env.tpl 2>/dev/null)
          set -l kv (string split -m 1 '=' $line)
          if test (count $kv) -ge 2
            set -gx $kv[1] $kv[2]
          end
        end
      end
    '';
  };
}
