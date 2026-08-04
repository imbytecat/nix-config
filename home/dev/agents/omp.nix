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

  # 与 codex 同款默认模型（openai/sol + high thinking）；smol 用 luna。
  # config.yml 是 `omp config set` / `/settings` 的写入目标，这里声明式接管后运行时改动会失败，
  # 与本仓其余 agent 配置同一取舍：改配置走 nix，不走 TUI。
  # setup 向导也因此必须在这里关掉：向导完成时要写 setupVersion 回 config.yml，只读 symlink 写
  # 不进去，导致每次启动都重跑 bootstrap。setupVersion 标记已完成 + startup.setupWizard 兜底
  # 禁用（上游 bump CURRENT_SETUP_VERSION 后前者会过期）。外观与全仓一致：catppuccin 主题 +
  # Nerd 字体图标（fonts.nix 已装 maple-mono NF）。
  ompConfig = {
    setupVersion = 1;
    startup.setupWizard = false;
    enableInstallTelemetry = false;
    theme = {
      dark = "dark-catppuccin";
      light = "light-catppuccin";
    };
    symbolPreset = "nerd";
    # web_search 把 Exa 排到链首（fish op-env 已注入 EXA_API_KEY），避免 auto 优先命中
    # Anthropic 并使用其固定的 Haiku 搜索模型。只是优先级、不是排他：Exa 失败仍会顺着
    # 内置顺序回退到 anthropic 等，要真正禁用得用 providers.webSearchExclude。
    # 旧的 providers.webSearch 枚举已被上游移除，只靠 legacy 迁移塞进本列表头部。
    providers.webSearchOrder = [ "exa" ];
    modelRoles = {
      default = "${catalog.ref "opus"}:max";
      smol = catalog.ref "luna";
      slow = "${catalog.ref "sol"}:xhigh";
      designer = catalog.ref "kimi";
    };
    # ponytail 走它自带的 pi extension（package.json 的 legacy `pi.extensions` 键，omp 的
    # loader 认）：before_agent_start 每轮把 ruleset 拼进 system prompt，注册 /ponytail 档位
    # 与 /ponytail-* 命令，skills/ 由 omp-plugins provider 一并挂上 —— 不用手铺 skill link，
    # 也不用把上游那份没有 frontmatter 的 rule 包一层。
    extensions = [ "${inputs.ponytail}" ];
  };

  # caveman 没有 pi extension，只能自己接：给上游那份 activate 规则包上 frontmatter 当
  # always-apply 灌进去（omp 分桶要求 alwaysApply / description / condition 至少有一个）。
  # skills 不用重复铺 —— codex.nix 已 link 到 ~/.codex/skills，omp 的 codex provider 会扫。
  # 临时关说 "normal mode"，永久关删这条 rule。
  cavemanRule = pkgs.writeText "caveman-rule.md" ''
    ---
    description: Caveman speech mode — terse replies, technical substance and code byte-exact
    alwaysApply: true
    ---

    ${builtins.readFile "${inputs.caveman}/src/rules/caveman-activate.md"}
  '';
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.omp ];

  home.file = {
    ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
    ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
    ".omp/agent/rules/caveman.md".source = cavemanRule;
  };
}
