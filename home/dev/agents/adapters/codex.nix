{
  aiCatalog,
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  configDir =
    if config.home.preferXdgDirectories then
      "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
    else
      ".codex";
  codexHome =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  managedConfig = config.home.file."${configDir}/config.toml".source;
in
{
  programs.codex = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.codex;

    settings = {
      model_provider = "furtherverse";
      model = aiCatalog.models.sol.id;
      forced_login_method = "api";
      check_for_update_on_startup = false;

      model_reasoning_effort = "medium";
      model_reasoning_summary = "auto";

      approval_policy = "never";
      sandbox_mode = "danger-full-access";

      model_context_window = aiCatalog.models.sol.context;
      model_auto_compact_token_limit = aiCatalog.models.sol.context * 3 / 4;

      history.persistence = "none";
      analytics.enabled = false;
      feedback.enabled = false;

      model_providers.furtherverse = {
        name = "Furtherverse";
        base_url = "${aiCatalog.gateway.endpoint}/v1";
        env_key = aiCatalog.gateway.apiKeyEnv;
        wire_api = "responses";
      };
    };
  };

  # Home Manager 默认把 config.toml 链到只读 store，Codex 无法持久化项目与 hook 信任。
  home.file."${configDir}/config.toml".enable = lib.mkForce false;
  home.activation.mutableCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    configPath=${lib.escapeShellArg "${codexHome}/config.toml"}
    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg codexHome}

    if [ -e "$configPath" ]; then
      dynamic="$(${pkgs.remarshal}/bin/remarshal --if toml --of json "$configPath")"
    else
      dynamic='{}'
    fi
    static="$(${pkgs.remarshal}/bin/remarshal --if toml --of json ${lib.escapeShellArg managedConfig})"
    merged="$(${pkgs.jq}/bin/jq -n '$dynamic * $static' --argjson dynamic "$dynamic" --argjson static "$static")"

    tmp="$configPath.tmp"
    printf '%s\n' "$merged" | ${pkgs.remarshal}/bin/remarshal --if json --of toml - "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "$configPath"
  '';
}
