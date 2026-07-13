{
  pkgs,
  inputs,
  system,
  ...
}:

let
  tomlFormat = pkgs.formats.toml { };

  catalog = import ../../ai-catalog.nix;

  nick = "furtherverse";
  modelId = "grok-4.5";
  modelMeta = catalog.furtherverseModels.${modelId};

  grokConfig = {
    models = {
      default = nick;
      default_reasoning_effort = "high";
    };

    model.${nick} = {
      model = modelId;
      base_url = "${catalog.endpoint}/v1";
      name = "${modelMeta.name}";
      env_key = catalog.apiKeyEnv;
      api_backend = "responses";
      context_window = modelMeta.context;
      supports_reasoning_effort = modelMeta.reasoning;
    };

    ui.permission_mode = "always-approve";
    sandbox.profile = "off";

    cli.auto_update = false;

    features = {
      telemetry = false;
      remote_fetch = false;
      codebase_indexing = false;
    };

    telemetry = {
      trace_upload = false;
      mixpanel_enabled = false;
    };

    harness.disable_codebase_upload = true;
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.grok ];

  home.file.".grok/config.toml".source = tomlFormat.generate "grok-config.toml" grokConfig;
}
