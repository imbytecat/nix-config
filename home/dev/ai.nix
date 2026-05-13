{ pkgs, ... }:

let
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
in
{
  home.packages = with pkgs; [
    llm-agents.claude-code
    llm-agents.opencode
    llm-agents.skills
  ];

  home.file.".claude/settings.json".text = builtins.toJSON claudeCodeSettings;
}
