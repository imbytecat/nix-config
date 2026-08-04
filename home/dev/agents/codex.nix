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

    # 不用 HM 的 `plugins`：它把插件 link 进 ~/.codex/plugins/cache/… 后仍要 codex 自己
    # 落盘安装（`codex plugin add` 会往那个 store symlink 里写，直接 EROFS），marketplace
    # 里只会留一条 "not installed"。skills 这条路是纯 symlink，codex 顺着链接读到仓库根的
    # .codex-plugin/plugin.json，照样按 `ponytail:<skill>` 命名空间挂载。
    skills = "${inputs.ponytail}/skills";

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
