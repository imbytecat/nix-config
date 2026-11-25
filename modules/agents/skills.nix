{
  aspects.homeManager.workstation =
    {
      agentBundles,
      inputs,
      lib,
      ...
    }:

    let
      skillsIn =
        dir:
        lib.mapAttrs (name: _: "${dir}/${name}") (
          lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
        );

      managedSkills = agentBundles.skills // skillsIn "${inputs.agent-browser}/skills";
    in
    {
      # 逐项链接，保留 ~/.agents/skills 可写供 CLI 安装其他 skill。
      home.file = lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".agents/skills/${name}" {
          inherit source;
        }
      ) managedSkills;
    };
}
