{
  config,
  pkgs,
  lib,
  ...
}:

let
  catalog = import ../ai-catalog.nix;

  envTpl = "${config.xdg.configHome}/op-env/env.tpl";
  envCache = "${config.xdg.cacheHome}/op-env/env.fish";
  teaTpl = "${config.xdg.configHome}/op-env/tea.yml.tpl";
  teaConfig = "${config.xdg.configHome}/tea/config.yml";
in
{
  # 模板只写 op:// 引用；真实密钥由 op-env-refresh 落到本机 0600 文件。
  xdg.configFile = {
    "op-env/env.tpl".text = ''
      set -gx ${catalog.gateway.apiKeyEnv} "{{ op://Developer/AI Gateway API/credential }}"

      set -gx EXA_API_KEY "{{ op://Developer/Exa API/credential }}"
      set -gx CONTEXT7_API_KEY "{{ op://Developer/Context7 API/credential }}"

      # GitHub API 必须用 token；SSH key 仅负责 git transport。
      set -gx GH_TOKEN "{{ op://Developer/GitHub CLI Token/credential }}"
    '';

    "op-env/tea.yml.tpl".text = ''
      logins:
        - name: furtherverse
          url: https://git.furtherverse.com
          token: "{{ op://Developer/Gitea CLI Token/credential }}"
          default: true
          ssh_host: git.furtherverse.net
          version_check: true
          user: imbytecat
    '';
  };

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
      # 启动只读缓存；token 由 local.fish 提供，refresh 手动拉取。
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
          for template in "${envTpl}" "${teaTpl}"
            if not test -f "$template"
              echo "op-env: template not found: $template" >&2
              return 1
            end
          end

          set -l cache_dir (path dirname "${envCache}")
          set -l tea_dir (path dirname "${teaConfig}")
          for dir in "$cache_dir" "$tea_dir"
            if not mkdir -p "$dir"; or not chmod 700 "$dir"
              echo "op-env: cannot prepare directory: $dir" >&2
              return 1
            end
          end

          set -l env_tmp (mktemp "$cache_dir/.tmp.XXXXXX")
          or begin
            echo "op-env: mktemp failed: $cache_dir" >&2
            return 1
          end
          set -l tea_tmp (mktemp "$tea_dir/.tmp.XXXXXX")
          or begin
            command rm -f "$env_tmp"
            echo "op-env: mktemp failed: $tea_dir" >&2
            return 1
          end

          if not op inject --in-file "${envTpl}" > "$env_tmp"
            command rm -f "$env_tmp" "$tea_tmp"
            echo "op-env: env inject failed; old files kept" >&2
            return 1
          end
          if not op inject --in-file "${teaTpl}" > "$tea_tmp"
            command rm -f "$env_tmp" "$tea_tmp"
            echo "op-env: tea inject failed; old files kept" >&2
            return 1
          end

          # 清除已从模板删除的旧变量。
          set -l old_vars
          if test -f "${envCache}"
            set old_vars (string match -rg 'set -gx (\S+)' < "${envCache}")
          end
          if not mv "$env_tmp" "${envCache}"; or not mv "$tea_tmp" "${teaConfig}"
            command rm -f "$env_tmp" "$tea_tmp"
            echo "op-env: cannot replace cached files" >&2
            return 1
          end
          for var in $old_vars
            set -e $var
          end
          if not source "${envCache}"
            echo "op-env: files written but env cache could not be sourced" >&2
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
          end
          command rm -f "${envCache}" "${teaConfig}"
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
