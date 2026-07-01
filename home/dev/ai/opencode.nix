{
  pkgs,
  lib,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  gatewayOptions = {
    baseURL = "{env:AI_GATEWAY_BASE_URL}/v1";
    apiKey = "{env:AI_GATEWAY_API_KEY}";
  };

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
        baseURL = "{env:AI_GATEWAY_BASE_URL}/v1beta";
      };
    };
    furtherverse = {
      name = "Furtherverse";
      npm = "@ai-sdk/openai-compatible";
      options = gatewayOptions;
      models = {
        "deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 1000000;
            output = 384000;
          };
        };
        "deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 1000000;
            output = 384000;
          };
        };
        "glm-5.1" = {
          name = "GLM-5.1";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 202752;
            output = 32768;
          };
        };
        "kimi-k2.6" = {
          name = "Kimi K2.6";
          reasoning = true;
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [ "text" ];
          };
          limit = {
            context = 262144;
            output = 65536;
          };
        };
        "mimo-v2.5" = {
          name = "MiMo-V2.5";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 1048576;
            output = 131072;
          };
        };
        "mimo-v2.5-pro" = {
          name = "MiMo-V2.5-Pro";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 1048576;
            output = 131072;
          };
        };
        "minimax-m3" = {
          name = "MiniMax M3";
          reasoning = true;
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [ "text" ];
          };
          limit = {
            context = 512000;
            output = 128000;
          };
        };
        "qwen3.6-plus" = {
          name = "Qwen3.6 Plus";
          reasoning = true;
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [ "text" ];
          };
          limit = {
            context = 1000000;
            output = 65536;
          };
        };
        "qwen3.7-max" = {
          name = "Qwen3.7 Max";
          reasoning = true;
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
          limit = {
            context = 1000000;
            output = 65536;
          };
        };
      };
    };
  };

  baseOpencode = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    provider = providers;
    permission."*" = "allow";
    experimental.disable_paste_summary = true;
  };

  defaultOpencode = baseOpencode // {
    model = "furtherverse/mimo-v2.5-pro";
    small_model = "furtherverse/deepseek-v4-flash";
  };

  omoOpencode = baseOpencode // {
    plugin = [ "oh-my-openagent@latest" ];
    model = "anthropic/claude-opus-4-8";
    small_model = "openai/deepseek-v4-flash";
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

  omoClaude = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      sisyphus = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      hephaestus = {
        model = "openai/gpt-5.5";
        variant = "high";
      };
      oracle = {
        model = "openai/gpt-5.5";
        variant = "high";
      };
      librarian = {
        model = "openai/gpt-5.4-mini";
      };
      explore = {
        model = "openai/gpt-5.4-mini";
      };
      multimodal-looker = {
        model = "openai/gpt-5.5";
        variant = "medium";
      };
      prometheus = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      metis = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      momus = {
        model = "openai/gpt-5.5";
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
        model = "google/gemini-3.1-pro-preview";
        variant = "high";
      };
      ultrabrain = {
        model = "openai/gpt-5.5";
        variant = "xhigh";
      };
      deep = {
        model = "openai/gpt-5.5";
        variant = "medium";
      };
      artistry = {
        model = "google/gemini-3.1-pro-preview";
        variant = "high";
      };
      quick = {
        model = "openai/gpt-5.4-mini";
      };
      unspecified-low = {
        model = "furtherverse/kimi-k2.6";
      };
      unspecified-high = {
        model = "anthropic/claude-opus-4-8";
        variant = "max";
      };
      writing = {
        model = "furtherverse/kimi-k2.6";
      };
    };
    experimental = omoExperimental;
    git_master = omoGitMaster;
  };

  omoGpt = lib.recursiveUpdate omoClaude {
    agents = {
      sisyphus = {
        model = "openai/gpt-5.5";
        variant = "high";
      };
      prometheus = {
        model = "openai/gpt-5.5";
        variant = "high";
      };
      metis = {
        model = "openai/gpt-5.5";
        variant = "high";
      };
    };
    categories.unspecified-high = {
      model = "openai/gpt-5.5";
      variant = "high";
    };
  };

  mkOmoProfile = name: variant: {
    "opencode-profiles/${name}/opencode.json".source =
      jsonFormat.generate "${name}-opencode.json" omoOpencode;
    "opencode-profiles/${name}/tui.json".source = jsonFormat.generate "${name}-tui.json" tui;
    "opencode-profiles/${name}/oh-my-openagent.json".source =
      jsonFormat.generate "${name}-omo.json" variant;
    "opencode-profiles/${name}/AGENTS.md".text = agentsMd;
  };
in
{
  home.packages = [ pkgs.llm-agents.opencode ];

  xdg.configFile = lib.mkMerge [
    {
      "opencode/opencode.json".source = jsonFormat.generate "opencode-default.json" defaultOpencode;
    }
    (mkOmoProfile "omo-claude" omoClaude)
    (mkOmoProfile "omo-gpt" omoGpt)
  ];
}
