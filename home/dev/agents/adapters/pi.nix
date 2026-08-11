{
  pkgs,
  inputs,
  system,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };
  catalog = import ../../../ai-catalog.nix;

  projectModel = m: {
    inherit (m) id name reasoning;
    input = builtins.filter (
      x:
      builtins.elem x [
        "text"
        "image"
      ]
    ) m.input;
    contextWindow = m.context;
    maxTokens = m.maxOutput;
  };
  familyModels = family: map projectModel (builtins.attrValues catalog.providers.${family});

  mkProvider = api: baseUrl: models: {
    inherit api baseUrl models;
    apiKey = "${"$"}${catalog.gateway.apiKeyEnv}";
  };

  piModels.providers = {
    furtherverse-anthropic = mkProvider "anthropic-messages" catalog.gateway.endpoint (
      familyModels "anthropic"
    );
    furtherverse-openai = mkProvider "openai-responses" "${catalog.gateway.endpoint}/v1" (
      familyModels "openai"
    );
    furtherverse-google = mkProvider "google-generative-ai" "${catalog.gateway.endpoint}/v1beta" (
      familyModels "google"
    );
    furtherverse = mkProvider "openai-completions" "${catalog.gateway.endpoint}/v1" (
      familyModels "furtherverse"
    );
  };

  piSettings = {
    defaultProvider = "furtherverse-openai";
    defaultModel = catalog.models.sol.id;
    defaultThinkingLevel = "high";
    enableInstallTelemetry = false;
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.pi ];

  # Pi 由 Nix 更新，不检查上游自更新。
  home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

  home.file = {
    ".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" piModels;
    ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" piSettings;
  };
}
