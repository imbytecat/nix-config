{
  pkgs,
  inputs,
  system,
  ...
}:

let
  tomlFormat = pkgs.formats.toml { };

  catalog = import ../../ai-catalog.nix;

  codexConfig = {
    model_provider = "furtherverse";
    model = catalog.models.sol.id;
    forced_login_method = "api";
    check_for_update_on_startup = false;

    model_reasoning_effort = "medium";
    model_reasoning_summary = "auto";

    approval_policy = "never";
    sandbox_mode = "danger-full-access";

    model_context_window = catalog.models.sol.context;
    model_auto_compact_token_limit = catalog.models.sol.context * 3 / 4;

    history.persistence = "none";
    analytics.enabled = false;
    feedback.enabled = false;

    model_providers.furtherverse = {
      name = "Furtherverse";
      base_url = "${catalog.gateway.endpoint}/v1";
      env_key = catalog.gateway.apiKeyEnv;
      wire_api = "responses";
    };
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.codex ];

  home.file.".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
}
