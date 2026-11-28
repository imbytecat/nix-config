# 原生 provider 继承客户端自带的模型和协议；只有网关 ID 不同的模型需要额外声明。
{ aiCatalog, lib }:
let
  apis = {
    anthropic = "anthropic-messages";
    openai = "openai-responses";
    deepseek = "openai-completions";
    moonshotai = "openai-completions";
    xai = "openai-responses";
  };

  routes = lib.mapAttrs (_: api: {
    inherit api;
    baseUrl = aiCatalog.gateway.endpoint + lib.optionalString (api != "anthropic-messages") "/v1";
  }) apis;
in
{
  mkProviders =
    {
      apiKey,
      aliasFields ? _: { },
    }:
    lib.mapAttrs (
      provider: models:
      let
        route = routes.${provider};
        aliases = builtins.filter (m: m.id != m.nativeId) (lib.attrValues models);
        alias =
          m:
          {
            inherit (route) api;
            inherit (m) id name reasoning;
            input = builtins.filter (
              type:
              builtins.elem type [
                "text"
                "image"
              ]
            ) m.input;
            contextWindow = m.context;
            maxTokens = m.maxOutput;
          }
          // aliasFields m;
      in
      {
        inherit apiKey;
        inherit (route) baseUrl;
      }
      // lib.optionalAttrs (aliases != [ ]) { models = map alias aliases; }
    ) aiCatalog.providers;
}
