{ inputs, ... }:

let
  manifest = builtins.fromJSON (builtins.readFile "${inputs.ponytail}/.codex-plugin/plugin.json");
in
{
  codex = {
    plugin = inputs.ponytail;
    inherit (manifest) name version;
  };

  omp.extensions = [ "${inputs.ponytail}" ];

  claude = {
    plugin = inputs.ponytail;
    # SessionStart hook 见 settings.json 没有 statusLine 就催一次，而 HM 的 settings 是只读
    # symlink，加不进去；预置它的一次性标记。
    files.".claude/.ponytail-statusline-nudged".text = "";
  };
}
