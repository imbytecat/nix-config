{
  aiCatalog,
  inputs,
  system,
  ...
}:

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

}
