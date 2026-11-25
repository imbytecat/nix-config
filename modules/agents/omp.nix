{
  aspects.homeManager.daily =
    {
      aiCatalog,
      pkgs,
      lib,
      inputs,
      ...
    }:

    let
      yamlFormat = pkgs.formats.yaml { };

      bundles = import ./_bundles { inherit inputs lib pkgs; };
      ompBundles = map (bundle: bundle.omp) (builtins.filter (bundle: bundle ? omp) bundles);
      bundleExtensions = lib.concatMap (bundle: bundle.extensions or [ ]) ompBundles;
      bundleFiles = lib.foldl' (files: bundle: files // (bundle.files or { })) { } ompBundles;

      gatewayProviders = import ./_gateway-providers.nix { inherit aiCatalog lib; };

      # apiKey 仅记录密钥环境变量名。
      # OMP 的原生 ID 是 moonshot，Pi 和 models.dev 用 moonshotai。
      providerId = family: if family == "moonshotai" then "moonshot" else family;
      ompModels.providers = lib.mapAttrs' (
        family: provider: lib.nameValuePair (providerId family) provider
      ) (gatewayProviders.mkProviders { apiKey = aiCatalog.gateway.apiKeyEnv; });
      role =
        nick: level:
        let
          model = aiCatalog.models.${nick};
        in
        "${providerId model.provider}/${model.id}:${aiCatalog.effortFor model level}";

      # config.yml 只读，禁用会尝试写 setupVersion 的向导。
      ompConfig = {
        setupVersion = 1;
        startup.setupWizard = false;
        enableInstallTelemetry = false;
        telemetry.otlpExportEnabled = false;
        dev.autoqa = false;
        theme = {
          dark = "dark-catppuccin";
          light = "light-catppuccin";
        };
        symbolPreset = "nerd";
        providers.webSearchOrder = [ "exa" ];
        compaction.thresholdPercent = 75;
        modelRoles = {
          default = role "opus" "max";
          smol = role "deepseek" "max";
          slow = role "fable" "xhigh";
        };
        extensions = bundleExtensions;
      };

    in
    {
      home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp ];

      home.file = {
        ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
        ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
      }
      // bundleFiles;
    };
}
