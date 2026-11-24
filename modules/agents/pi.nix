{
  aspects.homeManager.agent =
    {
      aiCatalog,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };
      deepseek = aiCatalog.models.deepseek;

      gatewayProviders = import ./_gateway-providers.nix { inherit aiCatalog lib; };

      # Pi 会给省略的常规档位补默认值；显式 null 才会从可选档位中排除。
      piEfforts = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
      piModels.providers = gatewayProviders.mkProviders {
        apiKey = "$" + aiCatalog.gateway.apiKeyEnv;
        aliasFields = model: {
          thinkingLevelMap =
            lib.genAttrs piEfforts (level: if builtins.elem level model.efforts then level else null)
            // {
              off = if model.canDisableThinking then "none" else null;
            };
        };
      };

      piSettings = {
        defaultProvider = deepseek.provider;
        enabledModels = map aiCatalog.ref (builtins.attrNames aiCatalog.models);
        defaultModel = deepseek.id;
        defaultThinkingLevel = aiCatalog.effortFor deepseek "max";
        enableInstallTelemetry = false;
      };
    in
    {
      home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi ];

      # 版本只随 Nix input 更新，启动时不查上游。
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

      home.file = {
        ".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" piModels;
        ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" piSettings;
      };
    };
}
