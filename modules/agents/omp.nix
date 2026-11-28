{
  aspects.homeManager.workstation =
    {
      agentBundles,
      aiCatalog,
      gatewayProviders,
      lib,
      llmAgents,
      pkgs,
      ...
    }:

    let
      yamlFormat = pkgs.formats.yaml { };

      bundleExtensions = lib.concatMap (bundle: bundle.extensions or [ ]) agentBundles.omp;
      bundleFiles = lib.mergeAttrsList (map (bundle: bundle.files or { }) agentBundles.omp);

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
        # ACP 只有显式配置 yolo 才跳过客户端的工具审批。
        tools.approvalMode = "yolo";
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
      home.packages = [ llmAgents.omp ];

      home.file = {
        ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
        ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
      }
      // bundleFiles;
    };
}
