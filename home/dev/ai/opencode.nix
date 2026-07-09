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

  # 把 catalog 的中性 per-model 元数据投影成 opencode provider.models schema。
  # furtherverse 的 key 即 model id；第一方（anthropic/openai/google）的 key 是 nick、id 在字段里，
  # 故按 .id 重命名后投影（非对称 keying 见 docs/adr/0005）。
  projectMeta = m: {
    inherit (m) name reasoning;
    modalities = { inherit (m) input output; };
    limit = {
      context = m.context;
      output = m.maxOutput;
    };
  };
  furtherverseModels = lib.mapAttrs (_id: projectMeta) catalog.furtherverseModels;
  byNick = lib.mapAttrs' (_nick: m: lib.nameValuePair m.id (projectMeta m));

  # 本地 id 简写：仅可读性糖，指向唯一真源 catalog（非第二别名层）
  opus = catalog.anthropicModels.opus.id;
  gpt = catalog.openaiModels.gpt.id;
  gptMini = catalog.openaiModels.gptMini.id;
  gemini = catalog.googleModels.gemini.id;

  providers = {
    anthropic = {
      npm = "@ai-sdk/anthropic";
      options = gatewayOptions;
      models = byNick catalog.anthropicModels;
    };
    openai = {
      npm = "@ai-sdk/openai";
      options = gatewayOptions;
      models = byNick catalog.openaiModels;
    };
    google = {
      npm = "@ai-sdk/google";
      options = gatewayOptions // {
        baseURL = "${catalog.endpoint}/v1beta";
      };
      models = byNick catalog.googleModels;
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
    experimental = {
      disable_paste_summary = true;
    };
    plugin = [ "oh-my-openagent@latest" ];
    model = "anthropic/${opus}";
    small_model = "openai/${gptMini}";
    compaction = {
      "auto" = true;
      "prune" = true;
      "reserved" = 15000;
    };
  };

  tui = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  agentsMd = ''
    # AGENTS.md

    - 默认始终使用简体中文回复。
    - 仅当用户明确要求时才使用英文。
  '';

  omoProfile = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      sisyphus = {
        model = "anthropic/${opus}";
        variant = "max";
      };
      hephaestus = {
        model = "openai/${gpt}";
        variant = "high";
      };
      oracle = {
        model = "openai/${gpt}";
        variant = "high";
      };
      librarian = {
        model = "openai/${gptMini}";
      };
      explore = {
        model = "openai/${gptMini}";
      };
      multimodal-looker = {
        model = "openai/${gpt}";
        variant = "medium";
      };
      prometheus = {
        model = "openai/${gpt}";
        variant = "high";
      };
      metis = {
        model = "openai/${gpt}";
        variant = "high";
      };
      momus = {
        model = "openai/${gpt}";
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
        model = "google/${gemini}";
        variant = "high";
      };
      ultrabrain = {
        model = "openai/${gpt}";
        variant = "xhigh";
      };
      deep = {
        model = "openai/${gpt}";
        variant = "high";
      };
      artistry = {
        model = "google/${gemini}";
        variant = "high";
      };
      quick = {
        model = "openai/${gptMini}";
      };
      unspecified-low = {
        model = "openai/${gpt}";
        variant = "medium";
      };
      unspecified-high = {
        model = "openai/${gpt}";
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
