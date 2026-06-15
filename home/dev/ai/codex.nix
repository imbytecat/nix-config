{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };

  codexConfig = {
    model_provider = "furtherverse";
    model = "gpt-5.5";
    forced_login_method = "api";

    model_reasoning_effort = "high";
    model_reasoning_summary = "auto";

    approval_policy = "never";
    sandbox_mode = "danger-full-access";

    model_context_window = 1000000;
    model_auto_compact_token_limit = 400000;

    history.persistence = "none";

    model_providers.furtherverse = {
      name = "Furtherverse";
      base_url = "https://ai-gateway.furtherverse.com/v1";
      env_key = "AI_GATEWAY_API_KEY";
      wire_api = "responses";
    };
  };
in
{
  home.packages = [ pkgs.llm-agents.codex ];

  home.file.".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
}
