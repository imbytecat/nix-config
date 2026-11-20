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
}
