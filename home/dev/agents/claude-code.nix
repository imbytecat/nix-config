{ pkgs, inputs, system, ... }:

let
  jsonFormat = pkgs.formats.json { };

  # ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN 环境变量（fish op-env 注入），这里只取模型 ID。
  catalog = import ../../ai-catalog.nix;

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
      ANTHROPIC_DEFAULT_OPUS_MODEL = catalog.anthropicModels.opus.id;
      ANTHROPIC_DEFAULT_SONNET_MODEL = catalog.anthropicModels.sonnet.id;
      ANTHROPIC_DEFAULT_HAIKU_MODEL = catalog.anthropicModels.haiku.id;
      CLAUDE_CODE_SUBAGENT_MODEL = catalog.anthropicModels.sonnet.id;

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
  home.packages = [ inputs.llm-agents.packages.${system}.claude-code ];

  home.file.".claude/settings.json".source =
    jsonFormat.generate "claude-settings.json" claudeCodeSettings;
}
