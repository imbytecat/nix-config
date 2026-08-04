{
  lib,
  inputs,
  system,
  ...
}:

let
  catalog = import ../../ai-catalog.nix;

  # HM 的 skills 只收「一个目录」或「name → 源」的 attrset，挂两个仓库就得自己合。
  skillsIn =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
    );
in
{
  programs.codex = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.codex;

    # 不用 HM 的 `plugins`：它把插件 link 进 ~/.codex/plugins/cache/… 后仍要 codex 自己
    # 落盘安装（`codex plugin add` 会往那个 store symlink 里写，直接 EROFS），marketplace
    # 里只会留一条 "not installed"。skills 这条路是纯 symlink，codex 顺着链接读到仓库根的
    # .codex-plugin/plugin.json，照样按 `<plugin>:<skill>` 命名空间挂载。
    # 这两份 link 同时也是 omp 的 skill 来源（它的 codex provider 扫 ~/.codex/skills）。
    skills = skillsIn "${inputs.ponytail}/skills" // skillsIn "${inputs.caveman}/skills";

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
