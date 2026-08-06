{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  manifest = {
    name = "caveman";
    version = "0.1.0";
    description = "Caveman always-on Codex hook";
    hooks = "./hooks.json";
  };

  plugin =
    pkgs.runCommandLocal "caveman-codex-plugin"
      {
        pname = manifest.name;
        inherit (manifest) version;
      }
      ''
        install -Dm444 ${inputs.caveman}/.codex/hooks.json "$out/hooks.json"
        install -Dm444 ${pkgs.writeText "caveman-plugin.json" (builtins.toJSON manifest)} "$out/.codex-plugin/plugin.json"
      '';

  rule = pkgs.writeText "caveman-rule.md" ''
    ---
    description: Caveman speech mode — terse replies, technical substance and code byte-exact
    alwaysApply: true
    ---

    ${builtins.readFile "${inputs.caveman}/src/rules/caveman-activate.md"}
  '';

  skills = lib.mapAttrs (name: _: "${inputs.caveman}/skills/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.caveman}/skills")
  );
in
{
  codex = {
    inherit plugin;
    inherit (manifest) name version;
    hookState."caveman@home-manager:hooks.json:session_start:0:0".trusted_hash =
      "sha256:0ed786805542f7114c30eda6945e72a2f1285c06fd6d4320de621a9549c095ed";
  };

  # caveman 无 Pi extension，OMP 继续用 always-apply rule 与显式命令。
  omp.files = {
    ".omp/agent/rules/caveman.md".source = rule;
    ".omp/agent/commands/caveman.md".source = "${inputs.caveman}/commands/caveman.md";
  };

  # cavecrew 依赖 Claude subagent，caveman-stats 依赖 session hook；OMP/Codex 均无法运行。
  skills = removeAttrs skills [
    "cavecrew"
    "caveman-stats"
  ];
}
