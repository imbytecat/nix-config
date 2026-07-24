{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  catalog = import ../../ai-catalog.nix;

  # 把 catalog 的中性 per-model 元数据投影成 pi models.json 的 model schema。
  # pi 的 input 只认 text/image，过滤掉 pdf/video/audio。
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
  familyModels = p: map projectModel (lib.attrValues (catalog.byProvider p));

  # "$ENV" 语法：pi 在运行时读环境变量（fish op-env 注入），密钥不落盘。
  apiKey = "$" + catalog.apiKeyEnv;

  mkProvider = api: baseUrl: models: {
    inherit
      api
      baseUrl
      apiKey
      models
      ;
  };

  piModels = {
    providers = {
      anthropic = mkProvider "anthropic-messages" catalog.endpoint (familyModels "anthropic");
      openai = mkProvider "openai-responses" "${catalog.endpoint}/v1" (familyModels "openai");
      google = mkProvider "google-generative-ai" "${catalog.endpoint}/v1beta" (familyModels "google");
      furtherverse = mkProvider "openai-completions" "${catalog.endpoint}/v1" (
        familyModels "furtherverse"
      );
    };
  };

  # 与 codex 同款默认模型（openai/sol）。
  piSettings = {
    defaultProvider = catalog.models.sol.provider;
    defaultModel = catalog.models.sol.id;
    defaultThinkingLevel = "high";
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.pi ];

  home.file = {
    ".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" piModels;
    ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" piSettings;
  };
}
