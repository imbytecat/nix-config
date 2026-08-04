{
  inputs,
  system,
  ...
}:

let
  # ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN 环境变量（fish op-env 注入），这里只取模型 ID。
  catalog = import ../../ai-catalog.nix;

  # 网关无法自动确认扩展上下文；目录标记为 1M 的模型在 Claude Code adapter 中追加选择标记。
  modelId = model: if model.context == 1000000 then "${model.id}[1m]" else model.id;
in
{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.claude-code;

    # claude-code >= 2.1.157 把 plugins 的每个 entry 直接 symlink 成 ~/.claude/skills/<name>
    # 的 personal plugin，manifest 里的 skills/commands/hooks/MCP 一起生效 —— 于是 ponytail
    # 的三个 lifecycle hook 不用在这里手抄，上游改文件名也不会静默失效。
    plugins.ponytail = inputs.ponytail;

    settings = {
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
  };

  # ponytail 的 SessionStart hook 发现 settings.json 里没有 statusLine 就会催一次「让 agent
  # 帮你加上」，而这里的 settings.json 是只读 symlink，加不进去。预先铺下它的一次性标记文件，
  # 把这条催促永久按掉。
  home.file.".claude/.ponytail-statusline-nudged".text = "";
}
