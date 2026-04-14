{ config, ... }:

let
  envTpl = "${config.xdg.configHome}/op-env/env.tpl";
in
{
  # ── 1Password env template ──────────────────────────
  # op:// references only — no real secrets, safe to commit
  # Kept outside ~/.config/op — that dir must be 700 and owned by op CLI
  xdg.configFile."op-env/env.tpl".text = ''
    set -gx AI_GATEWAY_BASE_URL "{{ op://Developer/AI Gateway API/URL }}"
    set -gx AI_GATEWAY_API_KEY "{{ op://Developer/AI Gateway API/credential }}"
    set -gx EXA_API_KEY "{{ op://Developer/Exa API/credential }}"
    set -gx CONTEXT7_API_KEY "{{ op://Developer/Context7 API/credential }}"
  '';

  programs.fish = {
    enable = true;

    shellAbbrs = {
      # Navigation (one-shot, no need to recall in history)
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    shellAliases = {
      # File listing (eza) — base aliases (ls/la/lt) from programs.eza
      ll = "eza -lh";
      lla = "eza -lah --time-style=long-iso";

      # Tools
      cat = "bat --paging=never";
      rm = "gomi";
      lg = "lazygit";
      vi = "nvim";
    };

    interactiveShellInit = ''
      # No greeting
      set -g fish_greeting

      # PATH
      fish_add_path $HOME/go/bin $HOME/.bun/bin

      # Sudo: double Escape to prepend sudo
      bind \e\e 'fish_commandline_prepend sudo'

      # WSL clipboard
      if set -q WSL_DISTRO_NAME
        alias pbcopy clip.exe
        alias pbpaste "powershell.exe -noprofile -c Get-Clipboard"
      end

      # User-local overrides
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end

      # 1Password → env vars (single op call, silent on failure)
      # Auth via OP_SERVICE_ACCOUNT_TOKEN (set it in ~/.config/fish/local.fish)
      function op-env --description "Load secrets from 1Password"
        if not type -q op; or not set -q OP_SERVICE_ACCOUNT_TOKEN; or not test -f ${envTpl}
          return 1
        end
        op inject --in-file ${envTpl} 2>/dev/null | source
      end
      op-env
    '';
  };
}
