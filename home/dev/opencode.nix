{
  pkgs,
  lib,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  # ============================================================
  # 共用的 AI Gateway providers / models
  # default 和 omo 走的是同一条 AI Gateway，所以同一张表
  # ============================================================
  gatewayOptions = {
    baseURL = "{env:AI_GATEWAY_BASE_URL}/v1";
    apiKey = "{env:AI_GATEWAY_API_KEY}";
  };

  providers = {
    anthropic = {
      name = "Anthropic";
      npm = "@ai-sdk/anthropic";
      options = gatewayOptions;
      models = {
        "claude-opus-4-7" = {
          name = "Claude Opus 4.7";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 1000000; output = 128000; };
        };
        "claude-sonnet-4-6" = {
          name = "Claude Sonnet 4.6";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 200000; output = 64000; };
        };
        "claude-haiku-4-5" = {
          name = "Claude Haiku 4.5";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 200000; output = 64000; };
        };
      };
    };
    openai = {
      name = "OpenAI";
      npm = "@ai-sdk/openai";
      options = gatewayOptions;
      models = {
        "gpt-5.5" = {
          name = "GPT-5.5";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 1050000; input = 920000; output = 130000; };
        };
        "gpt-5.4-mini" = {
          name = "GPT-5.4 mini";
          reasoning = true;
          modalities = {
            input = [ "text" "image" ];
            output = [ "text" ];
          };
          limit = { context = 400000; input = 272000; output = 128000; };
        };
      };
    };
    google = {
      name = "Google";
      npm = "@ai-sdk/google";
      options = gatewayOptions // {
        baseURL = "{env:AI_GATEWAY_BASE_URL}/v1beta";
      };
      models = {
        "gemini-3.1-pro-preview" = {
          name = "Gemini 3.1 Pro";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "video" "audio" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 1048576; output = 65536; };
        };
        "gemini-3-flash-preview" = {
          name = "Gemini 3 Flash";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "video" "audio" "pdf" ];
            output = [ "text" ];
          };
          limit = { context = 1048576; output = 65536; };
        };
      };
    };
    furtherverse = {
      name = "Furtherverse";
      npm = "@ai-sdk/openai-compatible";
      options = gatewayOptions;
      models = {
        "glm-5.1" = {
          name = "GLM-5.1";
          reasoning = true;
          modalities = { input = [ "text" ]; output = [ "text" ]; };
          limit = { context = 202752; output = 32768; };
        };
        "kimi-k2.6" = {
          name = "Kimi K2.6";
          reasoning = true;
          modalities = {
            input = [ "text" "image" "video" ];
            output = [ "text" ];
          };
          limit = { context = 262144; output = 65536; };
        };
        "kimi-k2.6-turbo" = {
          name = "Kimi K2.6 Turbo";
          reasoning = true;
          modalities = {
            input = [ "text" "image" ];
            output = [ "text" ];
          };
          limit = { context = 262000; output = 262000; };
        };
        "minimax-m2.7" = {
          name = "MiniMax M2.7";
          reasoning = true;
          modalities = { input = [ "text" ]; output = [ "text" ]; };
          limit = { context = 204800; output = 131072; };
        };
      };
    };
  };

  # 所有 opencode profile 共用的脚手架（schema / providers / permission / 等）
  baseOpencode = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    provider = providers;
    permission."*" = "allow";
    experimental.disable_paste_summary = true;
  };

  # 默认 ~/.config/opencode：kimi 主力，不挂 omo 插件
  defaultOpencode = baseOpencode // {
    model = "furtherverse/kimi-k2.6-turbo";
    small_model = "furtherverse/minimax-m2.7";
  };

  # omo 两套 profile 用同一份 opencode.json
  omoOpencode = baseOpencode // {
    plugin = [ "oh-my-openagent@latest" ];
    model = "anthropic/claude-opus-4-7";
    small_model = "openai/gpt-5.4-mini";
  };

  tui = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  agentsMd = ''
    # AGENTS.md

    - Always reply in Simplified Chinese by default.
    - Use English only if the user explicitly asks for it.
    - Keep code, commands, file paths, logs, and identifiers unchanged.
  '';

  # ============================================================
  # oh-my-openagent：两套 variant 仅 4 个字段不同，靠 recursiveUpdate 派生
  # ============================================================
  omoExperimental = {
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

  omoGitMaster = {
    commit_footer = false;
    include_co_authored_by = false;
    git_env_prefix = "GIT_MASTER=1";
  };

  # Claude variant（主力 = Claude Opus）
  omoClaude = {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      sisyphus = { model = "anthropic/claude-opus-4-7"; variant = "max"; };
      hephaestus = { model = "openai/gpt-5.5"; variant = "high"; };
      oracle = { model = "openai/gpt-5.5"; variant = "high"; };
      librarian = { model = "openai/gpt-5.4-mini"; };
      explore = { model = "openai/gpt-5.4-mini"; };
      multimodal-looker = { model = "openai/gpt-5.5"; variant = "medium"; };
      prometheus = { model = "anthropic/claude-opus-4-7"; variant = "max"; };
      metis = { model = "anthropic/claude-opus-4-7"; variant = "max"; };
      momus = { model = "openai/gpt-5.5"; variant = "xhigh"; };
      atlas = { model = "furtherverse/kimi-k2.6"; };
      sisyphus-junior = { model = "furtherverse/kimi-k2.6"; };
    };
    categories = {
      visual-engineering = { model = "google/gemini-3.1-pro-preview"; variant = "high"; };
      ultrabrain = { model = "openai/gpt-5.5"; variant = "xhigh"; };
      deep = { model = "openai/gpt-5.5"; variant = "medium"; };
      artistry = { model = "google/gemini-3.1-pro-preview"; variant = "high"; };
      quick = { model = "openai/gpt-5.4-mini"; };
      unspecified-low = { model = "furtherverse/kimi-k2.6"; };
      unspecified-high = { model = "anthropic/claude-opus-4-7"; variant = "max"; };
      writing = { model = "furtherverse/kimi-k2.6"; };
    };
    experimental = omoExperimental;
    git_master = omoGitMaster;
  };

  # GPT variant：sisyphus / prometheus / metis / unspecified-high 切到 gpt-5.5
  omoGpt = lib.recursiveUpdate omoClaude {
    agents = {
      sisyphus = { model = "openai/gpt-5.5"; variant = "high"; };
      prometheus = { model = "openai/gpt-5.5"; variant = "high"; };
      metis = { model = "openai/gpt-5.5"; variant = "high"; };
    };
    categories.unspecified-high = { model = "openai/gpt-5.5"; variant = "high"; };
  };

  mkOmoProfile = name: variant: {
    "opencode-profiles/${name}/opencode.json".source =
      jsonFormat.generate "${name}-opencode.json" omoOpencode;
    "opencode-profiles/${name}/tui.json".source =
      jsonFormat.generate "${name}-tui.json" tui;
    "opencode-profiles/${name}/oh-my-openagent.json".source =
      jsonFormat.generate "${name}-omo.json" variant;
    "opencode-profiles/${name}/AGENTS.md".text = agentsMd;
  };
in
{
  xdg.configFile = lib.mkMerge [
    {
      "opencode/opencode.json".source =
        jsonFormat.generate "opencode-default.json" defaultOpencode;
    }
    (mkOmoProfile "omo-claude" omoClaude)
    (mkOmoProfile "omo-gpt" omoGpt)
  ];
}
