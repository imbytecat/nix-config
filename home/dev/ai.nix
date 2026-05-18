{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };

  claudeCodeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    attribution = {
      commit = "";
      pr = "";
    };

    env = {
      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
      CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      DISABLE_AUTOUPDATER = "1";
      DISABLE_INSTALLATION_CHECKS = "1";
      ENABLE_TOOL_SEARCH = "false";
    };

    includeCoAuthoredBy = false;
    model = "opus[1m]";
    skipDangerousModePermissionPrompt = true;
  };

  codexConfig = {
    model_provider = "furtherverse";
    model = "gpt-5.5";
    model_reasoning_effort = "high";
    disable_response_storage = true;
    model_context_window = 1000000;
    model_auto_compact_token_limit = 400000;

    model_providers.furtherverse = {
      name = "Furtherverse";
      base_url = "https://ai-gateway.furtherverse.com/v1";
      wire_api = "responses";
      env_key = "AI_GATEWAY_API_KEY";
    };
  };
in
{
  home.packages = with pkgs; [
    llm-agents.claude-code
    llm-agents.codex
    llm-agents.opencode
    llm-agents.skills
  ];

  home.file.".claude/settings.json".text = builtins.toJSON claudeCodeSettings;
  home.file.".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
}
