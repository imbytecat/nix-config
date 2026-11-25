{
  aspects.homeManager.daily =
    {
      aiCatalog,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      bundles = import ./_bundles { inherit inputs lib pkgs; };
      claudePlugins = map (bundle: bundle.claude) (builtins.filter (bundle: bundle ? claude) bundles);

      # 网关不会替 Claude Code 确认扩展上下文；catalog 标为 1M 的模型加 [1m] 选择标记。
      modelId = model: if model.context == 1000000 then "${model.id}[1m]" else model.id;
    in
    {
      programs.claude-code = {
        enable = true;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
        plugins = lib.listToAttrs (
          map (
            plugin: lib.nameValuePair (lib.importJSON "${plugin}/.claude-plugin/plugin.json").name plugin
          ) claudePlugins
        );

        settings = {
          model = "opus";
          effortLevel = aiCatalog.effortFor aiCatalog.models.opus "xhigh";
          # 密钥只留在 网关环境变量里，不另设 ANTHROPIC_AUTH_TOKEN。
          apiKeyHelper = "printf %s \"\$${aiCatalog.gateway.apiKeyEnv}\"";

          permissions.defaultMode = "bypassPermissions";
          skipDangerousModePermissionPrompt = true;
          # 否则每个新域名先发给 api.anthropic.com 做安全检查。
          skipWebFetchPreflight = true;
          attribution = false;
          cleanupPeriodDays = 90;

          env = {
            ANTHROPIC_BASE_URL = aiCatalog.gateway.endpoint;
            ANTHROPIC_DEFAULT_FABLE_MODEL = modelId aiCatalog.models.fable;
            ANTHROPIC_DEFAULT_OPUS_MODEL = modelId aiCatalog.models.opus;
            ANTHROPIC_DEFAULT_SONNET_MODEL = modelId aiCatalog.models.sonnet;
            ANTHROPIC_DEFAULT_HAIKU_MODEL = modelId aiCatalog.models.haiku;
            CLAUDE_CODE_SUBAGENT_MODEL = modelId aiCatalog.models.sonnet;

            # 网关会丢 Anthropic 的 server tool（见 dsh.nix 的 web_search），tool search 一并关掉。
            ENABLE_TOOL_SEARCH = "false";

            # 遥测、错误上报、自动更新、/feedback 等非必要流量全关；版本只随 Nix 更新。
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            # 总开关在文档里是枚举清单，新通道另配开关；单项开关冗余写上，防以后收窄。
            DISABLE_TELEMETRY = "1";
            DISABLE_ERROR_REPORTING = "1";
            CLAUDE_CODE_DISABLE_FEATURE_FLAGS = "1";
            CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
            CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          };
        };
      };

      # ponytail 的 SessionStart hook 见 settings.json 没有 statusLine 就催一次，而这份 settings 是只读
      # symlink，加不进去；预置它的一次性标记。
      home.file.".claude/.ponytail-statusline-nudged".text = "";
    };
}
