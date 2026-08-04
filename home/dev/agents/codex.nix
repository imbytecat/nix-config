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

    # 不用 HM 的 `plugins`：它把插件 link 进 ~/.codex/plugins/cache/… 后，Codex 仍要
    # 往里面落盘安装，store symlink 会直接 EROFS。纯说明型 skill 统一由 skills.nix 铺到
    # 官方跨 agent 目录 ~/.agents/skills；需要可写状态的 plugin 继续交给 CLI。

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
