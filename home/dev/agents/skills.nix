{ lib, inputs, ... }:

let
  skillsIn =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
    );

  # 上游有两个 skill 在这里的两个 agent 上都是死的，不铺：
  # cavecrew 指名要 cavecrew-* subagent —— omp 只从 ~/.omp/agent/agents 认 omp schema 的定义
  # （上游那三份写的是 Claude 工具名 Read/Grep/Glob），Codex 也没有文件级 agent 定义，spawn 必失败；
  # caveman-stats 的数字由 Claude Code 的 mode-tracker hook 读 session log 注入，这里没有那个 hook。
  # 两者只会白占每轮 system prompt 的 skill 列表。
  deadSkills = [
    "cavecrew"
    "caveman-stats"
  ];

  managedSkills = removeAttrs (
    skillsIn "${inputs.ponytail}/skills"
    // skillsIn "${inputs.caveman}/skills"
    // skillsIn "${inputs.agent-browser}/skills"
    # mattpocock/skills 比前三家多一层分类目录，而 omp/Codex 的 skills provider 都只认
    # <root>/<name>/SKILL.md（非递归），所以逐类扫、link 仍是 flat 的。只取 engineering +
    # productivity 这 22 个（= 上游 .claude-plugin/plugin.json 的清单）：deprecated 与
    # in-progress 是弃用/半成品，misc 与 personal 是作者私活（git-guardrails 那个还是
    # Claude Code hook）。这里没有死 skill：一半带 disable-model-invocation，omp 归一化成
    # hide —— 不进每轮 system prompt 列表，仍可 /skill:<name> 手敲，Codex 侧等价开关在各自
    # agents/openai.yaml 的 policy.allow_implicit_invocation。
    // skillsIn "${inputs.mattpocock-skills}/skills/engineering"
    // skillsIn "${inputs.mattpocock-skills}/skills/productivity"
  ) deadSkills;
in
{
  # 逐个 link，保留 ~/.agents/skills 本身可写；Nix 管固定 skill，CLI 仍可安装其他名字。
  home.file = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".agents/skills/${name}" {
      inherit source;
    }
  ) managedSkills;
}
