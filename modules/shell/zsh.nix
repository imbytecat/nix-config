let
  enable = {
    programs.zsh.enable = true;
  };
in
{
  aspects.nixos.daily = enable;
  aspects.darwin.daily = enable;

  aspects.homeManager.daily =
    {
      aiCatalog,
      config,
      pkgs,
      lib,
      ...
    }:

    let
      envTpl = "${config.xdg.configHome}/op-env/env.tpl";
      teaTpl = "${config.xdg.configHome}/op-env/tea.yml.tpl";
      envDir = "${config.xdg.cacheHome}/op-env";
      # zsh 用 set -a 载入；Paseo 的 systemd 服务当 EnvironmentFile 读。
      envFile = "${envDir}/env";
      teaDir = "${config.xdg.configHome}/tea";
      teaConfig = "${teaDir}/config.yml";

      opEnvRefresh = pkgs.writeShellApplication {
        name = "op-env-refresh";
        text = ''
          : "''${OP_SERVICE_ACCOUNT_TOKEN:?op-env: OP_SERVICE_ACCOUNT_TOKEN is not set}"
          if ! command -v op >/dev/null; then
            echo "op-env: op CLI not found in PATH" >&2
            exit 1
          fi

          mkdir -p "${envDir}" "${teaDir}"
          chmod 700 "${envDir}" "${teaDir}"
          env_tmp=$(mktemp "${envDir}/.tmp.XXXXXX")
          tea_tmp=$(mktemp "${teaDir}/.tmp.XXXXXX")
          trap 'rm -f "$env_tmp" "$tea_tmp"' EXIT

          # 两份都注入成功才替换；任一失败，旧文件保持不动。
          op inject --in-file "${envTpl}" >"$env_tmp"
          op inject --in-file "${teaTpl}" >"$tea_tmp"
          mv "$env_tmp" "${envFile}"
          mv "$tea_tmp" "${teaConfig}"
          echo "op-env: refreshed"
        '';
      };
    in
    {
      # 模板只写 op:// 引用；真实密钥由 op-env-refresh 落到本机 0600 文件。
      xdg.configFile = {
        "op-env/env.tpl".text = ''
          ${aiCatalog.gateway.apiKeyEnv}="{{ op://Developer/AI Gateway API/credential }}"

          EXA_API_KEY="{{ op://Developer/Exa API/credential }}"
          DEEPSEEK_API_KEY="{{ op://Developer/DeepSeek API/credential }}"
          CONTEXT7_API_KEY="{{ op://Developer/Context7 API/credential }}"

          # GitHub API 必须用 token；SSH key 仅负责 git transport。
          GH_TOKEN="{{ op://Developer/GitHub CLI Token/credential }}"
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

      home.packages = [ opEnvRefresh ];

      home.sessionPath = [
        "$HOME/go/bin"
        "$HOME/.bun/bin"
      ]
      ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin "/Applications/Visual Studio Code.app/Contents/Resources/app/bin";

      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        # EDITOR=nvim 会让 zsh 默认用 vi 键位。
        defaultKeymap = "emacs";
        # 粘贴的命令里有 # 注释、没加引号的 ? 或 [] 时，照 bash 的行为执行。
        setOptions = [
          "INTERACTIVE_COMMENTS"
          "NO_NOMATCH"
        ];

        shellAliases = {
          # 尾随空格让 sudo 后面的别名也展开。
          sudo = "sudo ";
          ".." = "cd ..";
          "..." = "cd ../..";
          ll = "eza -lh";
          lla = "eza -lah --time-style=long-iso";
          cat = "bat --paging=never";
          lg = "lazygit";
        };

        initContent = lib.mkMerge [
          # 以下全是交互配置。Codex 的 shell 快照会非交互地 source .zshrc，并在每条 agent 命令前 source 快照：
          # 有这行守卫，快照只剩登录环境（实测 209 行，没有则是 7001 行插件函数）；直接 source .zshrc 的工具
          # 也拿不到 zoxide 接管的 cd（目标不存在时会跳去历史目录，`cd 不存在的目录 && rm -rf …` 会删错地方）。
          (lib.mkOrder 0 "[[ -o interactive ]] || return")
          ''
            _op_env_load() { [[ -f "${envFile}" ]] && { set -a; source "${envFile}"; set +a; } }
            _op_env_load
            # 包一层，让当前 shell 也拿到新值；token 来自 local.zsh，只在这次调用里导出。
            op-env-refresh() { OP_SERVICE_ACCOUNT_TOKEN=$OP_SERVICE_ACCOUNT_TOKEN command op-env-refresh && _op_env_load; }

            [[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
            # service account token 能读整个 vault：去掉导出标记，agent 等子进程不继承（omp 会把环境写进 daemon spec）。
            [[ -v OP_SERVICE_ACCOUNT_TOKEN ]] && typeset +x OP_SERVICE_ACCOUNT_TOKEN
          ''
        ];
      };
    };
}
