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

    # Codex 没有 rule 层，也吃不到 ponytail 的 pi extension（那是 omp 专属）：always-on 只能
    # 走全局 AGENTS.md（$CODEX_HOME/AGENTS.md，实测会进 model-visible prompt：
    # `codex debug prompt-input`）。skills 是被动的 —— 要模型自己想起来去 read，替代不了这层。
    # 两份都灌上游原文；规则里提到的 /caveman 档位命令 Codex 没有，未命中的 /x 会原样当文本
    # 送进去，语义照旧成立，所以不改写上游文本。
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
