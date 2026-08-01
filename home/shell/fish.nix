{
  config,
  pkgs,
  lib,
  ...
}:

let
  # AI 网关端点 / 密钥 env 名的唯一真源（见 home/ai-catalog.nix）；本模板是端点值与 key 变量名的
  # 定义处，codex/omp 从同一 catalog 消费，改名/换端点只此一处。
  catalog = import ../ai-catalog.nix;

  envTpl = "${config.xdg.configHome}/op-env/env.tpl";
  envCache = "${config.xdg.cacheHome}/op-env/env.fish";
in
{
  # 仅 op:// 引用，无真实密钥；放在 ~/.config/op 之外（op CLI 要求该目录 700）
  xdg.configFile."op-env/env.tpl".text = ''
    set -gx ${catalog.gateway.apiKeyEnv} "{{ op://Developer/AI Gateway API/credential }}"

    set -gx EXA_API_KEY "{{ op://Developer/Exa API/credential }}"
    set -gx CONTEXT7_API_KEY "{{ op://Developer/Context7 API/credential }}"

    # gh 的 API 认证只能用 token（SSH key 只管 git 传输层）。放这里而不是留在
    # keyring：keyring 那份是新机器上唯一还要 `gh auth login` 交互的东西。
    set -gx GH_TOKEN "{{ op://Developer/GitHub CLI Token/credential }}"

    set -gx ANTHROPIC_BASE_URL "${catalog.gateway.endpoint}"
    set -gx ANTHROPIC_AUTH_TOKEN "{{ op://Developer/AI Gateway API/credential }}"
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
      ll = "eza -lh";
      lla = "eza -lah --time-style=long-iso";

      cat = "bat --paging=never";
      rm = "gomi";
      lg = "lazygit";
    };

    functions = {
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
    };

    interactiveShellInit = ''
      set -g fish_greeting

      bind \e\e 'fish_commandline_prepend sudo'

      if test -f "${envCache}"
        source "${envCache}"
      end

      if test -f "${config.xdg.configHome}/fish/local.fish"
        source "${config.xdg.configHome}/fish/local.fish"
      end
    '';
  };
}
