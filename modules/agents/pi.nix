{ config, inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      host = config.flake.nixosConfigurations.awesome-devbox;
      files = host.config.home-manager.users.${host._module.specialArgs.username}.home.file;
    in
    {
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        # Pi 对不可用的默认档位会静默回退，直接检查新会话的实际状态。
        pi-default =
          pkgs.runCommand "check-pi-default"
            {
              nativeBuildInputs = [
                inputs.llm-agents.packages.${system}.pi
                pkgs.jq
              ];
              models = files.".pi/agent/models.json".source;
              settings = files.".pi/agent/settings.json".source;
            }
            ''
              set -o pipefail
              export HOME="$TMPDIR" PI_SKIP_VERSION_CHECK=1
              mkdir -p "$HOME/.pi/agent"
              jq '(.providers[].apiKey) = "test-key"' "$models" > "$HOME/.pi/agent/models.json"
              cp "$settings" "$HOME/.pi/agent/settings.json"
              printf '%s\n' '{"id":"default","type":"get_state"}' '{"id":"models","type":"get_available_models"}' \
                | pi --mode rpc --no-session --no-extensions \
                | jq -es --slurpfile settings "$settings" --slurpfile config "$models" '
                    (any(.[]; .id == "default" and .success and
                      ([.data.model.provider, .data.model.id, .data.thinkingLevel] ==
                       ($settings[0] | [.defaultProvider, .defaultModel, .defaultThinkingLevel]))))
                    and
                    (any(.[]; .id == "models" and .success and
                      ([.data.models[] | select(.baseUrl == $config[0].providers[.provider].baseUrl)
                        | "\(.provider)/\(.id)"] as $routed | ($settings[0].enabledModels - $routed) == [])))'
              touch "$out"
            '';
      };
    };

  aspects.homeManager.workstation =
    {
      aiCatalog,
      gatewayProviders,
      lib,
      llmAgents,
      pkgs,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };
      deepseek = aiCatalog.models.deepseek;

      # Pi 会给省略的常规档位补默认值；显式 null 才会从可选档位中排除。
      piEfforts = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
      piModels.providers = gatewayProviders.mkProviders {
        apiKey = "$" + aiCatalog.gateway.apiKeyEnv;
        aliasFields = model: {
          thinkingLevelMap =
            lib.genAttrs piEfforts (level: if builtins.elem level model.efforts then level else null)
            // {
              off = if model.canDisableThinking then "none" else null;
            };
        };
      };

      piSettings = {
        defaultProvider = deepseek.provider;
        enabledModels = map aiCatalog.ref (builtins.attrNames aiCatalog.models);
        defaultModel = deepseek.id;
        defaultThinkingLevel = aiCatalog.effortFor deepseek "max";
        enableInstallTelemetry = false;
      };
    in
    {
      home.packages = [ llmAgents.pi ];

      # 版本只随 Nix input 更新，启动时不查上游。
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

      home.file = {
        ".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" piModels;
        ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" piSettings;
      };
    };
}
