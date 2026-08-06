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
  bundles = import ../bundles { inherit inputs lib pkgs; };
  codexPlugins = map (bundle: bundle.codex) (builtins.filter (bundle: bundle ? codex) bundles);
  pluginCaches = map (
    plugin: "${codexHome}/plugins/cache/home-manager/${plugin.name}/${plugin.version}"
  ) codexPlugins;
  hookState = lib.foldl' (state: plugin: state // (plugin.hookState or { })) { } codexPlugins;
in
{
  programs.codex = {
    plugins = map (plugin: plugin.plugin) codexPlugins;
    settings = {
      features.hooks = true;
      hooks.state = hookState;
    };
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
}
