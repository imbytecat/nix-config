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
  # ── 1Password 环境变量模板 ─────────────────────────────
  # 仅包含 op:// 引用 — 无真实密钥，可安全提交
  # 放在 ~/.config/op 之外 — 该目录必须是 700 权限且属于 op CLI
  xdg.configFile."op-env/env.tpl".text = ''
    set -gx AI_GATEWAY_BASE_URL "{{ op://Developer/AI Gateway API/URL }}"
    set -gx AI_GATEWAY_API_KEY "{{ op://Developer/AI Gateway API/credential }}"
    set -gx EXA_API_KEY "{{ op://Developer/Exa API/credential }}"
    set -gx CONTEXT7_API_KEY "{{ op://Developer/Context7 API/credential }}"
  '';

  programs.fish = {
    enable = true;

    shellAbbrs = {
      # 导航（一次性命令，无需记录历史）
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    shellAliases = {
      # 文件列表（eza）— 基础别名（ls/la/lt）来自 programs.eza
      ll = "eza -lh";
      lla = "eza -lah --time-style=long-iso";

      cat = "bat --paging=never";
      rm = "gomi";
      lg = "lazygit";
    };

    interactiveShellInit = ''
      set -g fish_greeting
      fish_add_path $HOME/go/bin $HOME/.bun/bin
      ${lib.optionalString pkgs.stdenv.isDarwin ''fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"''}

      # 双击 Escape 在命令前插入 sudo
      bind \e\e 'fish_commandline_prepend sudo'

      # WSL 剪贴板
      if set -q WSL_DISTRO_NAME
        alias pbcopy clip.exe
        alias pbpaste "powershell.exe -noprofile -c Get-Clipboard"
      end

      # Windows Terminal：发送 OSC 9;9 使新标签页/窗格在同一目录打开
      function __wt_osc9_9 --on-variable PWD
        if test -n "$WT_SESSION"
          printf "\e]9;9;%s\e\\" (wslpath -w "$PWD")
        end
      end

      # 1Password → 环境变量（本地缓存，启动时不联网）
      # 启动时仅加载缓存；手动执行 op-env-refresh 拉取/更新
      # 通过 OP_SERVICE_ACCOUNT_TOKEN 认证（在 ~/.config/fish/local.fish 中设置）
      function op-env-refresh --description "Fetch secrets from 1Password and cache locally"
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
        # 替换缓存前记录旧变量名
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
      end

      function op-env-clear --description "Clear cached secrets"
        if test -f "${envCache}"
          for var in (string match -rg 'set -gx (\S+)' < "${envCache}")
            set -e $var
          end
          command rm -f "${envCache}"
        end
        echo "op-env: cleared"
      end

      # 加载缓存的密钥（即时，不联网）
      if test -f "${envCache}"
        source "${envCache}"
      end

      # 用户本地配置（OP_SERVICE_ACCOUNT_TOKEN、机器特定覆盖）
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end
    '';
  };
}
