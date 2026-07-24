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

  gatewayOptions = {
    baseURL = "${catalog.endpoint}/v1";
    apiKey = "{env:${catalog.apiKeyEnv}}";
  };

  # 把 catalog 的中性 per-model 元数据投影成 opencode provider.models schema。
  # furtherverse 的 key 即 model id；第一方（anthropic/openai/google）的 key 是 nick、id 在字段里，
  # 故按 .id 重命名后投影（非对称 keying）。
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

  fable = catalog.anthropicModels.fable.id;
  opus = catalog.anthropicModels.opus.id;
  sol = catalog.openaiModels.sol.id;
  terra = catalog.openaiModels.terra.id;
  luna = catalog.openaiModels.luna.id;
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
    small_model = "openai/${luna}";
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
    agents = {
      sisyphus = {
        model = "anthropic/${fable}";
        variant = "max";
      };
      hephaestus = {
        model = "openai/${sol}";
        variant = "medium";
      };
      oracle = {
        model = "openai/${sol}";
        variant = "xhigh";
      };
      librarian = {
        model = "furtherverse/grok-4.5";
      };
      explore = {
        model = "furtherverse/grok-4.5";
      };
      multimodal-looker = {
        model = "openai/${sol}";
        variant = "low";
      };
      prometheus = {
        model = "openai/${sol}";
        variant = "high";
      };
      metis = {
        model = "openai/${sol}";
        variant = "medium";
      };
      momus = {
        model = "openai/${terra}";
        variant = "high";
      };
      atlas = {
        model = "furtherverse/grok-4.5";
      };
      sisyphus-junior = {
        model = "furtherverse/grok-4.5";
      };
    };
    categories = {
      visual-engineering = {
        model = "google/${gemini}";
        variant = "high";
      };
      ultrabrain = {
        model = "openai/${sol}";
        variant = "xhigh";
      };
      deep = {
        model = "openai/${terra}";
        variant = "xhigh";
      };
      artistry = {
        model = "google/${gemini}";
        variant = "high";
      };
      quick = {
        model = "furtherverse/grok-4.5";
      };
      unspecified-low = {
        model = "openai/${luna}";
        variant = "xhigh";
      };
      unspecified-high = {
        model = "openai/${sol}";
        variant = "high";
      };
      writing = {
        model = "furtherverse/kimi-k3";
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
  home.packages = [ inputs.llm-agents.packages.${system}.opencode ];

  xdg.configFile = {
    "opencode/opencode.json".source = jsonFormat.generate "opencode.json" opencodeConfig;
    "opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" opencodeTui;
    "opencode/oh-my-openagent.json".source = jsonFormat.generate "oh-my-openagent.json" omoConfig;
    "opencode/AGENTS.md".text = agentsMd;
  };
}
