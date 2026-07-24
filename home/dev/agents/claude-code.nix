{
  pkgs,
  inputs,
  system,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  # ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN 环境变量（fish op-env 注入），这里只取模型 ID。
  catalog = import ../../ai-catalog.nix;

  # 网关无法自动确认扩展上下文；目录标记为 1M 的模型在 Claude Code adapter 中追加选择标记。
  modelId = model: if model.context == 1000000 then "${model.id}[1m]" else model.id;

  claudeCodeSettings = {
    effortLevel = "xhigh";

    permissions.defaultMode = "bypassPermissions";
    skipDangerousModePermissionPrompt = true;
    skipWebFetchPreflight = true;

    attribution = {
      commit = "";
      pr = "";
    };

    env = {
      ANTHROPIC_DEFAULT_FABLE_MODEL = modelId catalog.models.fable;
      ANTHROPIC_DEFAULT_OPUS_MODEL = modelId catalog.models.opus;
      ANTHROPIC_DEFAULT_SONNET_MODEL = modelId catalog.models.sonnet;
      ANTHROPIC_DEFAULT_HAIKU_MODEL = modelId catalog.models.haiku;
      CLAUDE_CODE_SUBAGENT_MODEL = modelId catalog.models.sonnet;

      ENABLE_TOOL_SEARCH = "false";

      CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
      DISABLE_AUTOUPDATER = "1";
    };

    cleanupPeriodDays = 90;
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.claude-code ];

  home.file.".claude/settings.json".source =
    jsonFormat.generate "claude-settings.json" claudeCodeSettings;
}
