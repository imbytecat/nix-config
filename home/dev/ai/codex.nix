{ pkgs, ... }:

let
  tomlFormat = pkgs.formats.toml { };

  # AI 网关端点 / provider 身份 / 模型目录的唯一真源（见 home/ai-catalog.nix）
  catalog = import ../../ai-catalog.nix;

  codexConfig = {
    model_provider = catalog.provider.id;
    model = catalog.openaiModels.sol.id;
    forced_login_method = "api";

    model_reasoning_effort = "high";
    model_reasoning_summary = "auto";

    approval_policy = "never";
    sandbox_mode = "danger-full-access";

    model_context_window = 1000000;
    model_auto_compact_token_limit = 400000;

    history.persistence = "none";

    model_providers.${catalog.provider.id} = {
      inherit (catalog.provider) name;
      base_url = "${catalog.endpoint}/v1";
      env_key = catalog.apiKeyEnv;
      wire_api = "responses";
    };
  };
in
{
  home.packages = [ pkgs.llm-agents.codex ];

  home.file.".codex/config.toml".source = tomlFormat.generate "codex-config.toml" codexConfig;
}
