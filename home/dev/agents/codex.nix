{
  inputs,
  system,
  ...
}:

let
  catalog = import ../../ai-catalog.nix;
in
{
  programs.codex = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.codex;

    # HM plugins 指向只读 store，Codex 写状态会 EROFS；skills 改铺 ~/.agents/skills。
    # Codex 无 rule/extension 层，always-on 原文只能经 context 写入全局 AGENTS.md。
    # 未知 /caveman 命令会按普通文本处理。
    context =
      builtins.readFile "${inputs.ponytail}/.agents/rules/ponytail.md"
      + "\n"
      + builtins.readFile "${inputs.caveman}/src/rules/caveman-activate.md";

    settings = {
      model_provider = "furtherverse";
      model = catalog.models.sol.id;
      forced_login_method = "api";
      check_for_update_on_startup = false;

      model_reasoning_effort = "medium";
      model_reasoning_summary = "auto";

      approval_policy = "never";
      sandbox_mode = "danger-full-access";

      model_context_window = catalog.models.sol.context;
      model_auto_compact_token_limit = catalog.models.sol.context * 3 / 4;

      history.persistence = "none";
      analytics.enabled = false;
      feedback.enabled = false;

      model_providers.furtherverse = {
        name = "Furtherverse";
        base_url = "${catalog.gateway.endpoint}/v1";
        env_key = catalog.gateway.apiKeyEnv;
        wire_api = "responses";
      };
    };
  };
}
