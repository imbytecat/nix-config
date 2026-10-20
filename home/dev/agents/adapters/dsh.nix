{
  aiCatalog,
  pkgs,
  lib,
  inputs,
  system,
  ...
}:

let
  yamlFormat = pkgs.formats.yaml { };

  model = aiCatalog.models.deepseek;
  gatewayProviders = import ./gateway-providers.nix { inherit aiCatalog lib; };
  gateway = (gatewayProviders.mkProviders aiCatalog.gateway.apiKeyEnv).${model.provider};

  # home 级 patch 叠在每个 profile 之后；按 id 整行替换 config，
  # 因此 UI 写进 profile patch 的同名行会被这里覆盖。
  dshPatch = [
    {
      id = "llm-pi-ai";
      config.providers.${model.provider} = {
        inherit (gateway) api;
        apiKeyEnv = gateway.apiKey;
        baseURL = gateway.baseUrl;
        reasoning = "high";
        models = [
          {
            inherit (model) id name input;
            contextWindow = model.context;
            maxTokens = model.maxOutput;
            # 网关把 reasoning_effort=off 映射为关闭思考；留空则 DeepSeek 默认继续思考。
            reasoningEfforts = {
              off = "off";
              low = "low";
              high = "high";
              max = "max";
            };
          }
        ];
      };
    }
    {
      id = "agent-default-model";
      config = {
        inherit (model) provider;
        model = model.id;
      };
    }
  ];
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.dsh ];

  home.file.".dsh/cordis.patch.yml".source = yamlFormat.generate "dsh-cordis.patch.yml" dshPatch;
}
