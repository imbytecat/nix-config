{
  config,
  pkgs,
  lib,
  ...
}:

let
  envTpl = "${config.xdg.configHome}/op-env/env.tpl";
  envCache = "${config.xdg.cacheHome}/op-env/env.fish";
in
{
  # 仅 op:// 引用，无真实密钥；放在 ~/.config/op 之外（op CLI 要求该目录 700）
  xdg.configFile."op-env/env.tpl".text = ''
    set -gx AI_GATEWAY_BASE_URL "{{ op://Developer/AI Gateway API/URL }}"
    set -gx AI_GATEWAY_API_KEY "{{ op://Developer/AI Gateway API/credential }}"
    set -gx EXA_API_KEY "{{ op://Developer/Exa API/credential }}"
    set -gx CONTEXT7_API_KEY "{{ op://Developer/Context7 API/credential }}"
    set -gx TANSTACK_API_KEY "{{ op://Developer/TanStack API/credential }}"
  '';

  home.sessionPath = [
    "$HOME/go/bin"
    "$HOME/.bun/bin"
  ]
  ++ lib.optional pkgs.stdenv.isDarwin "/Applications/Visual Studio Code.app/Contents/Resources/app/bin";

  programs.fish = {
    enable = true;

    shellAbbrs = {
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    shellAliases = {
      # ls/la/lt 来自 programs.eza
      ll = "eza -lh";
      lla = "eza -lah --time-style=long-iso";

      cat = "bat --paging=never";
      rm = "gomi";
      lg = "lazygit";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # WSL：Windows 剪贴板桥接
      pbcopy = "clip.exe";
      pbpaste = "powershell.exe -noprofile -c Get-Clipboard";
    };

    functions = lib.mkMerge [
      {
        # 启动只加载缓存，手动 refresh 拉取；OP_SERVICE_ACCOUNT_TOKEN 在 ~/.config/fish/local.fish
        op-env-refresh = {
          description = "Fetch secrets from 1Password and cache locally";
          body = ''
            if not type -q op
              echo "op-env: op CLI not found in PATH" >&2
              return 1
            end
            if not set -q OP_SERVICE_ACCOUNT_TOKEN; or test -z "$OP_SERVICE_ACCOUNT_TOKEN"
              echo "op-env: OP_SERVICE_ACCOUNT_TOKEN is not set" >&2
              return 1
            end
            if not test -f "${envTpl}"
              echo "op-env: template not found: ${envTpl}" >&2
              return 1
            end
            set -l cache_dir (path dirname "${envCache}")
            if not mkdir -p "$cache_dir"; or not chmod 700 "$cache_dir"
              echo "op-env: cannot prepare cache dir: $cache_dir" >&2
              return 1
            end
            set -l tmp (mktemp "$cache_dir/.tmp.XXXXXX")
            or begin
              echo "op-env: mktemp failed" >&2
              return 1
            end
            if not op inject --in-file "${envTpl}" > "$tmp"
              command rm -f "$tmp"
              echo "op-env: inject failed; old cache kept" >&2
              return 1
            end
            # 记录旧变量名，确保被删除的密钥也从环境中移除
            set -l old_vars
            if test -f "${envCache}"
              set old_vars (string match -rg 'set -gx (\S+)' < "${envCache}")
            end
            if not mv "$tmp" "${envCache}"
              command rm -f "$tmp"
              echo "op-env: cannot replace cache file" >&2
              return 1
            end
            for var in $old_vars
              set -e $var
            end
            if not source "${envCache}"
              echo "op-env: cache written but could not be sourced" >&2
              return 1
            end
            echo "op-env: refreshed"
          '';
        };

        op-env-clear = {
          description = "Clear cached secrets";
          body = ''
            if test -f "${envCache}"
              for var in (string match -rg 'set -gx (\S+)' < "${envCache}")
                set -e $var
              end
              command rm -f "${envCache}"
            end
            echo "op-env: cleared"
          '';
        };
      }
      (lib.mkIf pkgs.stdenv.isLinux {
        # Windows Terminal OSC 9;9：新标签页/窗格在同一目录打开
        __wt_osc9_9 = {
          onVariable = "PWD";
          body = ''
            if test -n "$WT_SESSION"
              printf "\e]9;9;%s\e\\" (wslpath -w "$PWD")
            end
          '';
        };
      })
    ];

    interactiveShellInit = ''
      set -g fish_greeting

      bind \e\e 'fish_commandline_prepend sudo'

      if test -f "${envCache}"
        source "${envCache}"
      end

      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end
    '';
  };
}
