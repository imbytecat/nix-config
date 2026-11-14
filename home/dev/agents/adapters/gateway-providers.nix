# OMP models.yml 与 DSH llm-pi-ai 共用 catalog→gateway provider 投影，单一化于此；
# OMP 整体写入，DSH 只取 api/baseUrl/apiKey。
{ aiCatalog, lib }:

let
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

  # path 是各 wire API 的版本前缀，挂在 gateway endpoint 后。
  apis = {
    anthropic = {
      api = "anthropic-messages";
      path = "";
    };
    openai = {
      api = "openai-responses";
      path = "/v1";
    };
    google = {
      api = "google-generative-ai";
      path = "/v1beta";
    };
    furtherverse = {
      api = "openai-completions";
      path = "/v1";
    };
  };
in
{
  # apiKey → { <family> = { api, baseUrl, models, apiKey }; }
  mkProviders =
    apiKey:
    builtins.mapAttrs (family: spec: {
      inherit (spec) api;
      inherit apiKey;
      baseUrl = "${aiCatalog.gateway.endpoint}${spec.path}";
      models = map projectModel (lib.attrValues aiCatalog.providers.${family});
    }) apis;
}
