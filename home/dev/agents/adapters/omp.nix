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

  gatewayProviders = import ./gateway-providers.nix { inherit aiCatalog lib; };

  # apiKey 仅记录密钥环境变量名。
  ompModels.providers = gatewayProviders.mkProviders aiCatalog.gateway.apiKeyEnv;

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
