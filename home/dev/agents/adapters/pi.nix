{
  aiCatalog,
  pkgs,
  lib,
  inputs,
  system,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  gatewayProviders = import ./gateway-providers.nix { inherit aiCatalog lib; };

  # Pi 的 apiKey 走 shell expansion。
  providers = gatewayProviders.mkProviders "${"$"}${aiCatalog.gateway.apiKeyEnv}";

  piModels.providers = {
    furtherverse-anthropic = providers.anthropic;
    furtherverse-openai = providers.openai;
    furtherverse-google = providers.google;
    furtherverse = providers.furtherverse // {
      compat.supportsDeveloperRole = false;
    };
  };

  piSettings = {
    defaultProvider = "furtherverse";
    defaultModel = aiCatalog.models.ds.id;
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
