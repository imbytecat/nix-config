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

  # 上游命令从 git 根目录找脚本，只在 caveman 自己的仓库里成立；插件里改指 store 中的脚本，
  # 脚本靠 __dirname 找 ../src/hooks 与 skills。上游改写法时求值直接报错，不再静默失效。
  upstreamHooks = builtins.readFile "${inputs.caveman}/.codex/hooks.json";
  gitRootScript = "$(git rev-parse --show-toplevel)/.codex/codex-sessionstart.js";
  hooks =
    assert lib.assertMsg (lib.hasInfix gitRootScript upstreamHooks)
      "caveman: upstream .codex/hooks.json no longer resolves codex-sessionstart.js from the git root";
    pkgs.writeText "caveman-hooks.json" (
      builtins.replaceStrings
        [ gitRootScript ]
        [
          "${inputs.caveman}/.codex/codex-sessionstart.js"
        ]
        upstreamHooks
    );

  plugin =
    pkgs.runCommandLocal "caveman-codex-plugin"
      {
        pname = manifest.name;
        inherit (manifest) version;
      }
      ''
        install -Dm444 ${hooks} "$out/hooks.json"
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
  };

  # caveman 无 Pi extension，OMP 继续用 always-apply rule 与显式命令。
  omp.files = {
    ".omp/agent/rules/caveman.md".source = rule;
    ".omp/agent/commands/caveman.md".source = "${inputs.caveman}/commands/caveman.md";
  };

  claude.plugin = inputs.caveman;

  # cavecrew 依赖 Claude subagent，caveman-stats 依赖 session hook；OMP/Codex 均无法运行。
  skills = removeAttrs skills [
    "cavecrew"
    "caveman-stats"
  ];
}
