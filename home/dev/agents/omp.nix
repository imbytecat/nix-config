{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:

let
  yamlFormat = pkgs.formats.yaml { };

  catalog = import ../../ai-catalog.nix;

  # 把 catalog 的中性 per-model 元数据投影成 omp models.yml 的 model schema。
  # omp 的 input 只认 text/image，过滤掉 pdf/video/audio。
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
  familyModels = p: map projectModel (lib.attrValues catalog.providers.${p});

  mkProvider = api: baseUrl: models: {
    inherit api baseUrl models;
    # omp 的 apiKey 值先按环境变量名解析（无 $ 前缀语法；fish op-env 注入），密钥不落盘。
    apiKey = catalog.gateway.apiKeyEnv;
  };

  ompModels = {
    providers = {
      anthropic = mkProvider "anthropic-messages" catalog.gateway.endpoint (familyModels "anthropic");
      openai = mkProvider "openai-responses" "${catalog.gateway.endpoint}/v1" (familyModels "openai");
      google = mkProvider "google-generative-ai" "${catalog.gateway.endpoint}/v1beta" (
        familyModels "google"
      );
      furtherverse = mkProvider "openai-completions" "${catalog.gateway.endpoint}/v1" (
        familyModels "furtherverse"
      );
    };
  };

  # 与 codex 同款默认模型（openai/sol + high thinking）；smol 对齐 opencode small_model（luna）。
  # config.yml 是 `omp config set` / `/settings` 的写入目标，这里声明式接管后运行时改动会失败，
  # 与本仓其余 agent 配置同一取舍：改配置走 nix，不走 TUI。
  # setup 向导也因此必须在这里关掉：向导完成时要写 setupVersion 回 config.yml，只读 symlink 写
  # 不进去，导致每次启动都重跑 bootstrap。setupVersion 标记已完成 + startup.setupWizard 兜底
  # 禁用（上游 bump CURRENT_SETUP_VERSION 后前者会过期）。外观与全仓一致：catppuccin 主题 +
  # Nerd 字体图标（fonts.nix 已装 maple-mono NF）。
  ompConfig = {
    setupVersion = 1;
    startup.setupWizard = false;
    theme = {
      dark = "dark-catppuccin";
      light = "light-catppuccin";
    };
    symbolPreset = "nerd";
    modelRoles = {
      default = "${catalog.ref "sol"}:high";
      smol = catalog.ref "luna";
    };
  };
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.omp ];

  home.file = {
    ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
    ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
  };
}
