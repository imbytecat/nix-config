{
  aspects.homeManager.workstation =
    {
      agentBundles,
      aiCatalog,
      config,
      lib,
      llmAgents,
      pkgs,
      ...
    }:

    let
      # HM 的 codex 模块只在 preferXdgDirectories 时改用 ~/.config/codex；本仓不开，开了会在下面取 source 时求值失败。
      configDir = ".codex";
      codexHome = "${config.home.homeDirectory}/${configDir}";
      managedConfig = config.home.file."${configDir}/config.toml".source;
      pluginCaches = map (
        plugin: "${codexHome}/plugins/cache/home-manager/${plugin.name}/${plugin.version}"
      ) agentBundles.codex;
    in
    {
      programs.codex = {
        enable = true;
        package = llmAgents.codex;
        plugins = map (plugin: plugin.plugin) agentBundles.codex;

        settings = {
          model_provider = "openai";
          openai_base_url = "${aiCatalog.gateway.endpoint}/v1";
          cli_auth_credentials_store = "file";
          model = aiCatalog.models.sol.id;
          forced_login_method = "api";
          check_for_update_on_startup = false;

          model_reasoning_effort = aiCatalog.effortFor aiCatalog.models.sol "xhigh";
          model_reasoning_summary = "auto";

          approval_policy = "never";
          sandbox_mode = "danger-full-access";

          model_context_window = aiCatalog.models.sol.context;
          model_auto_compact_token_limit = aiCatalog.models.sol.context * 3 / 4;

          history.persistence = "none";
          analytics.enabled = false;
          feedback.enabled = false;

          features.hooks = true;
        };
      };

      # Home Manager 默认把 config.toml 链到只读 store，Codex 无法持久化项目与 hook 信任。
      home.file."${configDir}/config.toml".enable = lib.mkForce false;
      home.activation.mutableCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          format = "toml";
          empty = "{}";
          jqOperation = "$dynamic * $static";
          path = "${codexHome}/config.toml";
          staticSettings = managedConfig;
        }
      );

      # Codex 0.146 不把 HM cache symlink 视为已安装，激活后落成可清理实体目录。
      home.activation.materializeCodexPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        for pluginCache in ${lib.concatMapStringsSep " " lib.escapeShellArg pluginCaches}; do
          if [ -L "$pluginCache" ]; then
            pluginSource="$(${pkgs.coreutils}/bin/readlink -f "$pluginCache")"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$pluginCache"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -R "$pluginSource" "$pluginCache"
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod -R u+w "$pluginCache"
          fi
        done
      '';

      # Codex 把 hook 信任钉在声明与整个插件目录的 hash 上，插件或 Codex 一更新就失效且静默失败。
      # 这里 Codex 本来就是 never 审批 + 完全访问，激活时照 TUI 审批的做法信任它在用户级列出的全部 hook。
      home.activation.trustCodexHooks =
        lib.hm.dag.entryAfter [ "materializeCodexPlugins" "mutableCodexConfig" ]
          ''
            $DRY_RUN_CMD env CODEX_HOME=${lib.escapeShellArg codexHome} \
              ${lib.getExe pkgs.python3} ${./_codex-hook-trust.py} \
              ${lib.getExe config.programs.codex.package} \
              || echo "warning: Codex hooks remain untrusted" >&2
          '';
    };
}
