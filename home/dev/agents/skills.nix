{ lib, inputs, ... }:

let
  skillsIn =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
    );

  # cavecrew 依赖 Claude subagent，caveman-stats 依赖 session hook；OMP/Codex 均无法运行。
  deadSkills = [
    "cavecrew"
    "caveman-stats"
  ];

  managedSkills = removeAttrs (
    skillsIn "${inputs.ponytail}/skills"
    // skillsIn "${inputs.caveman}/skills"
    // skillsIn "${inputs.agent-browser}/skills"
    # mattpocock skills 多一层分类，故逐类扁平链接；只接官方 engineering/productivity 清单。
    # 隐式调用开关由各 provider 原生策略处理。
    // skillsIn "${inputs.mattpocock-skills}/skills/engineering"
    // skillsIn "${inputs.mattpocock-skills}/skills/productivity"
  ) deadSkills;
in
{
  # 逐项链接，保留 ~/.agents/skills 可写供 CLI 安装其他 skill。
  home.file = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".agents/skills/${name}" {
      inherit source;
    }
  ) managedSkills;
}
