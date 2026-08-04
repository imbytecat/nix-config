{ lib, inputs, ... }:

let
  skillsIn =
    dir:
    lib.mapAttrs (name: _: "${dir}/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
    );

  managedSkills =
    skillsIn "${inputs.ponytail}/skills"
    // skillsIn "${inputs.caveman}/skills"
    // skillsIn "${inputs.agent-browser}/skills";
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
