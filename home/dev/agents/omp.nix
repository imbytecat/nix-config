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
    # omp 从环境变量名解析 apiKey，密钥不落盘。
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

  # config.yml 是只读 symlink；禁用 setup 向导，避免它因无法写 setupVersion 而反复运行。
  ompConfig = {
    setupVersion = 1;
    startup.setupWizard = false;
    enableInstallTelemetry = false;
    theme = {
      dark = "dark-catppuccin";
      light = "light-catppuccin";
    };
    symbolPreset = "nerd";
    # Exa 优先；失败时保留 omp 内置 provider 回退链。
    providers.webSearchOrder = [ "exa" ];
    compaction.thresholdPercent = 75;
    modelRoles = {
      default = "${catalog.ref "sol"}:xhigh";
      smol = catalog.ref "luna";
    };
    # 上游 extension 同时提供 ruleset、命令和 skills；omp 会按 realpath 去重共享 skills。
    extensions = [ "${inputs.ponytail}" ];
  };

  # caveman 没有 pi extension；包装 activate rule 为 always-apply，skills 复用 ~/.agents/skills。
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
    # `/caveman` 需要 native command；其余命令已有 skill 或依赖未接入的 Claude Code hook。
    ".omp/agent/commands/caveman.md".source = "${inputs.caveman}/commands/caveman.md";
  };
}
