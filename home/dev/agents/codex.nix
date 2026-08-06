{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  catalog = import ../../ai-catalog.nix;
  codexHome =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  cavemanManifest = {
    name = "caveman";
    version = "0.1.0";
    description = "Caveman always-on Codex hook";
    hooks = "./hooks.json";
  };
  cavemanPlugin =
    pkgs.runCommandLocal "caveman-codex-plugin"
      {
        pname = cavemanManifest.name;
        inherit (cavemanManifest) version;
      }
      ''
        install -Dm444 ${inputs.caveman}/.codex/hooks.json "$out/hooks.json"
        install -Dm444 ${pkgs.writeText "caveman-plugin.json" (builtins.toJSON cavemanManifest)} "$out/.codex-plugin/plugin.json"
      '';
  ponytailManifest = builtins.fromJSON (
    builtins.readFile "${inputs.ponytail}/.codex-plugin/plugin.json"
  );
  pluginCaches = [
    "${codexHome}/plugins/cache/home-manager/${cavemanManifest.name}/${cavemanManifest.version}"
    "${codexHome}/plugins/cache/home-manager/${ponytailManifest.name}/${ponytailManifest.version}"
  ];
in
{
  programs.codex = {
    enable = true;
    package = inputs.llm-agents.packages.${system}.codex;

    plugins = [
      cavemanPlugin
      inputs.ponytail
    ];

    settings = {
      features.hooks = true;

      # config.toml 只读，预信任 pin 住的 hook 定义；上游变更 hash 后会 fail closed。
      hooks.state = {
        "caveman@home-manager:hooks.json:session_start:0:0".trusted_hash =
          "sha256:0ed786805542f7114c30eda6945e72a2f1285c06fd6d4320de621a9549c095ed";
        "ponytail@home-manager:hooks/claude-codex-hooks.json:session_start:0:0".trusted_hash =
          "sha256:5f81d38f47448a1581c08ec877e044d9e04dd6f814dce3f2671f7a8edadd719b";
        "ponytail@home-manager:hooks/claude-codex-hooks.json:subagent_start:0:0".trusted_hash =
          "sha256:1423b56c1322f96c8f74c51c1e7ae9a047b904c1fa43ee9165d462fd7a6e70ef";
        "ponytail@home-manager:hooks/claude-codex-hooks.json:user_prompt_submit:0:0".trusted_hash =
          "sha256:6a6f42bc3b58d6262db38bfd74d7f340fcca2b09cdb134aad365063f0bfefca4";
      };

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

  # Codex 0.146 只把真实 cache 目录视为已安装；HM 的 symlink 先落地成可清理副本。
  home.activation.materializeCodexPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for pluginCache in ${lib.concatMapStringsSep " " lib.escapeShellArg pluginCaches}; do
      if [ -L "$pluginCache" ]; then
        pluginSource="$(${pkgs.coreutils}/bin/readlink -f "$pluginCache")"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$pluginCache"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -R "$pluginSource" "$pluginCache"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod -R u+w "$pluginCache"
      fi
    done
  '';
}
