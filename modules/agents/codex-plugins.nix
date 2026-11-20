{
  aspects.homeManager.daily =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:

    let
      codexHome =
        if config.home.preferXdgDirectories then
          "${config.xdg.configHome}/codex"
        else
          "${config.home.homeDirectory}/.codex";
      bundles = import ./_bundles { inherit inputs lib pkgs; };
      codexPlugins = map (bundle: bundle.codex) (builtins.filter (bundle: bundle ? codex) bundles);
      pluginCaches = map (
        plugin: "${codexHome}/plugins/cache/home-manager/${plugin.name}/${plugin.version}"
      ) codexPlugins;
    in
    {
      programs.codex = {
        plugins = map (plugin: plugin.plugin) codexPlugins;
        settings.features.hooks = true;
      };

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
