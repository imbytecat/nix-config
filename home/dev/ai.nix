{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };

  claudeCodeSettings = {
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
    model = "gpt-5-codex";
    model_provider = "ai-gateway";
    approval_policy = "on-request";

    model_providers.ai-gateway = {
      name = "AI Gateway";
      base_url = "https://ai-gateway.furtherverse.com/v1";
      env_key = "AI_GATEWAY_API_KEY";
      wire_api = "chat";
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
