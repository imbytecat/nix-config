{ pkgs, ... }:

let
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
in
{
  home.packages = with pkgs; [
    llm-agents.claude-code
    llm-agents.skills
  ];

  home.file.".claude/settings.json".source =
    jsonFormat.generate "claude-settings.json" claudeCodeSettings;
}
