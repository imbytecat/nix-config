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
  };

  # ponytail 在 omp 这边没有 adapter（claude-code / codex 各自走 HM 模块的 plugins 选项）：
  # skills 逐个 link 进原生目录即可，rule 得自己补 frontmatter —— 上游那份不带 frontmatter，
  # 而 omp 分桶要求 alwaysApply / description / condition 至少有一个，否则整条被静默丢弃
  # （既不注入也读不到 rule://）。删掉 alwaysApply 那行就退回 rulebook，由模型自己决定读不读。
  ponytailSkills = lib.listToAttrs (
    map
      (name: {
        name = ".omp/agent/skills/${name}";
        value.source = "${inputs.ponytail}/skills/${name}";
      })
      (
        lib.attrNames (
          lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${inputs.ponytail}/skills")
        )
      )
  );

  ponytailRule = pkgs.writeText "ponytail-rule.md" ''
    ---
    description: Lazy senior dev ladder — ask whether the code needs to exist before writing it
    alwaysApply: true
    ---

    ${builtins.readFile "${inputs.ponytail}/.agents/rules/ponytail.md"}
  '';
in
{
  home.packages = [ inputs.llm-agents.packages.${system}.omp ];

  home.file = ponytailSkills // {
    ".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" ompModels;
    ".omp/agent/config.yml".source = yamlFormat.generate "omp-config.yml" ompConfig;
    ".omp/agent/rules/ponytail.md".source = ponytailRule;
  };
}
