{
  pkgs,
  lib,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  # AI 网关端点 / provider 身份 / 模型目录的唯一真源（见 home/ai-catalog.nix）
  catalog = import ../../ai-catalog.nix;

  # 端点走 Nix-time 字面量（非密钥）；密钥仍走 opencode 运行时 {env:...} 模板
  gatewayOptions = {
    baseURL = "${catalog.endpoint}/v1";
    apiKey = "{env:${catalog.apiKeyEnv}}";
  };

  # 把 catalog 的中性 per-model 元数据投影成 opencode provider.models schema
  furtherverseModels = lib.mapAttrs (_id: m: {
    inherit (m) name reasoning;
    modalities = { inherit (m) input output; };
    limit = {
      context = m.context;
      output = m.maxOutput;
    };
  }) catalog.furtherverseModels;

  providers = {
    anthropic = {
      npm = "@ai-sdk/anthropic";
      options = gatewayOptions;
    };
    openai = {
      npm = "@ai-sdk/openai";
      options = gatewayOptions;
    };
    google = {
      npm = "@ai-sdk/google";
      options = gatewayOptions // {
        baseURL = "${catalog.endpoint}/v1beta";
      };
    };
    furtherverse = {
      inherit (catalog.provider) name npm;
      options = gatewayOptions;
      models = furtherverseModels;
    };
  };

  # 只用 opencode 是为了 oh-my-openagent，故 omo 即唯一配置：直接写默认 ~/.config/opencode/，
  # 不再分 default / profile 两套，也不需要 shell 里切 OPENCODE_CONFIG_DIR。
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    provider = providers;
    permission."*" = "allow";
    experimental.disable_paste_summary = true;
    plugin = [ "oh-my-openagent@latest" ];
    model = "anthropic/${catalog.models.opus}";
    small_model = "openai/${catalog.models.gptMini}";
  };

  tui = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  agentsMd = ''
    # AGENTS.md

    - 默认始终使用简体中文回复。
    - 仅当用户明确要求时才使用英文。
    - 保持代码、命令、文件路径、日志和标识符不变。
  '';

  omoProfile = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      sisyphus = {
        model = "anthropic/${catalog.models.opus}";
        variant = "max";
      };
      hephaestus = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      oracle = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      librarian = {
        model = "openai/${catalog.models.gptMini}";
      };
      explore = {
        model = "openai/${catalog.models.gptMini}";
      };
      multimodal-looker = {
        model = "openai/${catalog.models.gpt}";
        variant = "medium";
      };
      prometheus = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      metis = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      momus = {
        model = "openai/${catalog.models.gpt}";
        variant = "xhigh";
      };
      atlas = {
        model = "furtherverse/kimi-k2.6";
      };
      sisyphus-junior = {
        model = "furtherverse/kimi-k2.6";
      };
    };
    categories = {
      visual-engineering = {
        model = "google/${catalog.models.gemini}";
        variant = "high";
      };
      ultrabrain = {
        model = "openai/${catalog.models.gpt}";
        variant = "xhigh";
      };
      deep = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      artistry = {
        model = "google/${catalog.models.gemini}";
        variant = "high";
      };
      quick = {
        model = "openai/${catalog.models.gptMini}";
      };
      unspecified-low = {
        model = "openai/${catalog.models.gpt}";
        variant = "medium";
      };
      unspecified-high = {
        model = "openai/${catalog.models.gpt}";
        variant = "high";
      };
      writing = {
        model = "furtherverse/kimi-k2.6";
      };
    };
    experimental = {
      disable_omo_env = true;
      dynamic_context_pruning = {
        enabled = true;
        notification = "detailed";
        turn_protection = {
          enabled = true;
          turns = 3;
        };
        protected_tools = [
          "task"
          "todowrite"
          "todoread"
          "lsp_rename"
          "session_read"
          "session_write"
          "session_search"
        ];
        strategies = {
          deduplication.enabled = true;
          supersede_writes = {
            enabled = true;
            aggressive = false;
          };
          purge_errors = {
            enabled = true;
            turns = 5;
          };
        };
      };
    };
    git_master = {
      commit_footer = false;
      include_co_authored_by = false;
      git_env_prefix = "GIT_MASTER=1";
    };
    codegraph = {
      enabled = true;
      auto_init = true;
      auto_provision = true;
    };
  };
in
{
  home.packages = [ pkgs.llm-agents.opencode ];

  xdg.configFile = {
    "opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;
    "opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" tui;
    "opencode/oh-my-openagent.json".source = jsonFormat.generate "oh-my-openagent.json" omoProfile;
    "opencode/AGENTS.md".text = agentsMd;
  };
}
