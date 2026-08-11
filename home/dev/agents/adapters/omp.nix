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

  bundles = import ../bundles { inherit inputs lib pkgs; };
  ompBundles = map (bundle: bundle.omp) (builtins.filter (bundle: bundle ? omp) bundles);
  bundleExtensions = lib.concatMap (bundle: bundle.extensions or [ ]) ompBundles;
  bundleFiles = lib.foldl' (files: bundle: files // (bundle.files or { })) { } ompBundles;

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
  familyModels = p: map projectModel (lib.attrValues aiCatalog.providers.${p});

  mkProvider = api: baseUrl: models: {
    inherit api baseUrl models;
    # 仅记录密钥环境变量名。
    apiKey = aiCatalog.gateway.apiKeyEnv;
  };

  ompModels = {
    providers = {
      anthropic = mkProvider "anthropic-messages" aiCatalog.gateway.endpoint (familyModels "anthropic");
      openai = mkProvider "openai-responses" "${aiCatalog.gateway.endpoint}/v1" (familyModels "openai");
      google = mkProvider "google-generative-ai" "${aiCatalog.gateway.endpoint}/v1beta" (
        familyModels "google"
      );
      furtherverse = mkProvider "openai-completions" "${aiCatalog.gateway.endpoint}/v1" (
        familyModels "furtherverse"
      );
    };
  };

  # config.yml 只读，禁用会尝试写 setupVersion 的向导。
  ompConfig = {
    setupVersion = 1;
    startup.setupWizard = false;
    enableInstallTelemetry = false;
    dev.autoqa = false;
    theme = {
      dark = "dark-catppuccin";
      light = "light-catppuccin";
    };
    symbolPreset = "nerd";
    providers.webSearchOrder = [ "exa" ];
    compaction.thresholdPercent = 75;
    modelRoles = {
      default = "${aiCatalog.ref "sol"}:xhigh";
      smol = aiCatalog.ref "luna";
    };
    extensions = bundleExtensions;
  };

in
{
  home.packages = [ inputs.llm-agents.packages.${system}.omp ];

  home.file = {
    ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
    ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
  }
  // bundleFiles;
}
