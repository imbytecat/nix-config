{
  aspects.homeManager.agent =
    {
      aiCatalog,
      pkgs,
      lib,
      inputs,
      ...
    }:

    let
      yamlFormat = pkgs.formats.yaml { };

      model = aiCatalog.models.deepseek;
      gatewayProviders = import ./_gateway-providers.nix { inherit aiCatalog lib; };
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
            reasoning = "max";
            models = [
              {
                inherit (model) id name input;
                contextWindow = model.context;
                maxTokens = model.maxOutput;
                reasoningEfforts = {
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
        # FEEDBACK_ONLY 会在点赞/点踩/feedback 后把整段 session log 传到 dsh-otel-collector.deepseeksvc.com；
        # 与 DSH_TELEMETRY_DISABLED 生成的启动 patch 相同，不依赖启动环境。
        {
          id = "session-telemetry-otel";
          disabled = true;
        }
        # 网关会丢弃 DeepSeek 原生 web_search server tool，搜索只能直连官方 DEEPSEEK_API_KEY；
        # 用 Search/Fetch API（不耗模型 token）。本地 http fetch 的 SSRF 校验拒绝 mihomo fake-ip（198.18.0.0/15），
        # 在网关后面任何域名都抓不到。config 整行替换，两项都要写明。
        {
          id = "web";
          config = {
            searchProvider = "deepseek-search-api";
            fetchProvider = "deepseek-fetch-api";
          };
        }
        # 新会话默认完全访问且不弹审批（同 Codex 的 never + danger-full-access），/permission 仍可按会话切换。
        # config 整行替换：照抄上游的三个预设，否则 read-only 会从选择器消失。
        {
          id = "permission";
          config = {
            presets = {
              read-only = {
                sandbox = "read-only";
                approval = "ask";
              };
              workspace-write = {
                sandbox = "workspace-write";
                approval = "ask";
              };
              danger-full-access = {
                sandbox = "danger-full-access";
                approval = "never";
              };
            };
            defaultPreset = "danger-full-access";
          };
        }
      ];
    in
    {
      home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.dsh ];

      home.file.".dsh/cordis.patch.yml".source = yamlFormat.generate "dsh-cordis.patch.yml" dshPatch;
    };
}
