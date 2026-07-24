{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  catalog = import ../../ai-catalog.nix;
  omo = inputs.llm-agents.packages.${system}.oh-my-opencode;

  gatewayOptions = {
    baseURL = "${catalog.gateway.endpoint}/v1";
    apiKey = "{env:${catalog.gateway.apiKeyEnv}}";
  };

  # 把 catalog 的中性 per-model 元数据投影成 opencode provider.models schema。
  # catalog 统一以 nick 为 key、id 在字段里，这里一律按 .id 重命名后投影（对称 keying）。
  projectMeta = m: {
    inherit (m) name reasoning;
    modalities = { inherit (m) input output; };
    limit = {
      context = m.context;
      output = m.maxOutput;
    };
  };
  byId = ms: lib.mapAttrs' (_nick: m: lib.nameValuePair m.id (projectMeta m)) ms;
  familyModels = p: byId catalog.providers.${p};

  # "provider/id" 限定名（如 ref "opus" → "anthropic/claude-opus-4-8"），下方模型指派全用它。
  inherit (catalog) ref;

  providers = {
    anthropic = {
      name = "Anthropic";
      npm = "@ai-sdk/anthropic";
      options = gatewayOptions;
      models = familyModels "anthropic";
    };
    openai = {
      name = "OpenAI";
      npm = "@ai-sdk/openai";
      options = gatewayOptions;
      models = familyModels "openai";
    };
    google = {
      name = "Google";
      npm = "@ai-sdk/google";
      options = gatewayOptions // {
        baseURL = "${catalog.gateway.endpoint}/v1beta";
      };
      models = familyModels "google";
    };
    furtherverse = {
      name = "Furtherverse";
      npm = "@ai-sdk/openai-compatible";
      options = gatewayOptions;
      models = familyModels "furtherverse";
    };
  };

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    provider = providers;
    permission."*" = "allow";
    experimental = {
      disable_paste_summary = true;
    };
    model = (ref "opus");
    small_model = (ref "luna");
    compaction = {
      "auto" = true;
      "prune" = true;
      "reserved" = 30000;
    };
  };

  opencodeTui = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  omoConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    telemetry = false;
    disabled_hooks = [ "auto-update-checker" ];
    agents = {
      sisyphus = {
        model = (ref "fable");
        variant = "max";
      };
      hephaestus = {
        model = (ref "sol");
        variant = "medium";
      };
      oracle = {
        model = (ref "sol");
        variant = "xhigh";
      };
      librarian = {
        model = (ref "grok");
      };
      explore = {
        model = (ref "grok");
      };
      multimodal-looker = {
        model = (ref "sol");
        variant = "low";
      };
      prometheus = {
        model = (ref "sol");
        variant = "high";
      };
      metis = {
        model = (ref "sol");
        variant = "medium";
      };
      momus = {
        model = (ref "terra");
        variant = "high";
      };
      atlas = {
        model = (ref "grok");
      };
      sisyphus-junior = {
        model = (ref "grok");
      };
    };
    categories = {
      visual-engineering = {
        model = (ref "gemini");
        variant = "high";
      };
      ultrabrain = {
        model = (ref "sol");
        variant = "xhigh";
      };
      deep = {
        model = (ref "terra");
        variant = "xhigh";
      };
      artistry = {
        model = (ref "gemini");
        variant = "high";
      };
      quick = {
        model = (ref "grok");
      };
      unspecified-low = {
        model = (ref "luna");
        variant = "xhigh";
      };
      unspecified-high = {
        model = (ref "sol");
        variant = "high";
      };
      writing = {
        model = (ref "kimi");
      };
    };
    experimental = {
      disable_omo_env = true;
      dynamic_context_pruning.enabled = true;
    };
    git_master = {
      commit_footer = false;
      include_co_authored_by = false;
    };
    codegraph = {
      enabled = true;
      auto_init = true;
      auto_provision = true;
      telemetry = false;
    };
    browser_automation_engine.provider = "agent-browser";
    disabled_skills = [ "playwright" ];
  };

  agentsMd = ''
    # AGENTS.md

    - 【必须】所有情况下始终使用简体中文 (zh-CN) 进行回复。
  '';
in
{
  home.packages = [
    inputs.llm-agents.packages.${system}.opencode
    omo
  ];

  xdg.configFile = {
    "opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;
    "opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" opencodeTui;
    "opencode/oh-my-openagent.json".source = jsonFormat.generate "oh-my-openagent.json" omoConfig;
    "opencode/plugins/oh-my-openagent.js".source = "${omo}/lib/oh-my-opencode/dist/index.js";
    "opencode/AGENTS.md".text = agentsMd;
  };
}
