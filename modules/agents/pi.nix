{
  aspects.homeManager.daily =
    {
      aiCatalog,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };

      gatewayProviders = import ./_gateway-providers.nix { inherit aiCatalog lib; };

      # Pi 的 apiKey 支持 $NAME 环境变量插值，密钥只留在 op-env。
      providers = gatewayProviders.mkProviders ("$" + aiCatalog.gateway.apiKeyEnv);

      # 与内置 provider 同名会改写内置那份；加前缀，/login 的官方 provider 保持原样。
      piModels.providers = {
        furtherverse-anthropic = providers.anthropic;
        furtherverse-openai = providers.openai;
        furtherverse = providers.furtherverse // {
          compat.supportsDeveloperRole = false;
        };
      };

      piSettings = {
        defaultProvider = "furtherverse-anthropic";
        defaultModel = aiCatalog.models.opus.id;
        defaultThinkingLevel = "max";
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
