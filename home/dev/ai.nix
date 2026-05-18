{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  claudeCodeSettings = {
    effortLevel = "max";

    permissions.defaultMode = "bypassPermissions";
    skipDangerousModePermissionPrompt = true;

    includeCoAuthoredBy = false;
    attribution = {
      commit = "";
      pr = "";
    };

    env = {
      ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-7";
      ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-4-6";
      ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5";
      CLAUDE_CODE_SUBAGENT_MODEL = "claude-sonnet-4-6";

      CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
      CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1";
      ENABLE_TOOL_SEARCH = "false";

      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      DISABLE_AUTOUPDATER = "1";
      DISABLE_INSTALLATION_CHECKS = "1";
    };

    cleanupPeriodDays = 90;
  };

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
  home.packages = with pkgs; [
    llm-agents.claude-code
    llm-agents.codex
    llm-agents.opencode
    llm-agents.skills
  ];

  home.file.".claude/settings.json".source =
    jsonFormat.generate "claude-settings.json" claudeCodeSettings;

  home.file.".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
}
