{ inputs, ... }:

let
  manifest = builtins.fromJSON (builtins.readFile "${inputs.ponytail}/.codex-plugin/plugin.json");
in
{
  codex = {
    plugin = inputs.ponytail;
    inherit (manifest) name version;

    # config.toml 只读，预信任 pin 住的 hook 定义；上游变更 hash 后会 fail closed。
    hookState = {
      "ponytail@home-manager:hooks/claude-codex-hooks.json:session_start:0:0".trusted_hash =
        "sha256:5f81d38f47448a1581c08ec877e044d9e04dd6f814dce3f2671f7a8edadd719b";
      "ponytail@home-manager:hooks/claude-codex-hooks.json:subagent_start:0:0".trusted_hash =
        "sha256:1423b56c1322f96c8f74c51c1e7ae9a047b904c1fa43ee9165d462fd7a6e70ef";
      "ponytail@home-manager:hooks/claude-codex-hooks.json:user_prompt_submit:0:0".trusted_hash =
        "sha256:6a6f42bc3b58d6262db38bfd74d7f340fcca2b09cdb134aad365063f0bfefca4";
    };
  };

  omp.extensions = [ "${inputs.ponytail}" ];
}
