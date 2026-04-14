{ config, ... }:

let
  envTpl = "${config.xdg.configHome}/op-env/env.tpl";
  envCache = "${config.xdg.cacheHome}/op-env/env.fish";
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

      cat = "bat --paging=never";
      rm = "gomi";
      lg = "lazygit";
    };

    interactiveShellInit = ''
      set -g fish_greeting
      fish_add_path $HOME/go/bin $HOME/.bun/bin

      # Sudo: double Escape to prepend sudo
      bind \e\e 'fish_commandline_prepend sudo'

      # WSL clipboard
      if set -q WSL_DISTRO_NAME
        alias pbcopy clip.exe
        alias pbpaste "powershell.exe -noprofile -c Get-Clipboard"
      end

      # 1Password → env vars (cached locally, no network on shell start)
      # Startup only sources the cache; run op-env-refresh manually to fetch/update.
      # Auth via OP_SERVICE_ACCOUNT_TOKEN (set it in ~/.config/fish/local.fish)
      function op-env-refresh --description "Fetch secrets from 1Password and cache locally"
        if not type -q op; or not set -q OP_SERVICE_ACCOUNT_TOKEN; or not test -f "${envTpl}"
          echo "op-env: need op CLI + OP_SERVICE_ACCOUNT_TOKEN" >&2
          return 1
        end
        set -l cache_dir (path dirname "${envCache}")
        if not mkdir -p "$cache_dir"; or not chmod 700 "$cache_dir"
          echo "op-env: cannot create cache dir" >&2
          return 1
        end
        set -l tmp (mktemp "$cache_dir/.tmp.XXXXXX")
        or begin
          echo "op-env: mktemp failed" >&2
          return 1
        end
        if op inject --in-file "${envTpl}" > "$tmp" 2>/dev/null
          chmod 600 "$tmp"
          mv "$tmp" "${envCache}"
          source "${envCache}"
          echo "op-env: refreshed"
        else
          rm -f "$tmp"
          echo "op-env: failed (old cache kept)" >&2
          return 1
        end
      end

      function op-env-clear --description "Clear cached secrets"
        rm -f "${envCache}"
      end

      # Source cached secrets (instant, no network)
      if test -f "${envCache}"
        source "${envCache}"
      end

      # User-local config (OP_SERVICE_ACCOUNT_TOKEN, per-machine overrides)
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end
    '';
  };
}
