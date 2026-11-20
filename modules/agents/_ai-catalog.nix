# AI 网关与模型元数据真源；Codex、OMP、DSH 与 op-env 共用（agents/default.nix 注入为 aiCatalog）。
let
  # endpoint 不含 /v1；adapter 自加版本路径，密钥仅通过 env。
  # 避免 AI_GATEWAY_*：Vercel AI SDK 会自动读取并误路由。
  gateway = {
    endpoint = "https://ai-gateway.furtherverse.net";
    apiKeyEnv = "FURTHERVERSE_API_KEY";
  };

  providers = {
    anthropic = {
      fable = {
        id = "claude-fable-5-2";
        name = "Claude Fable 5.2";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1000000;
        maxOutput = 128000;
      };
      opus = {
        id = "claude-opus-5-5";
        name = "Claude Opus 5.5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1000000;
        maxOutput = 128000;
      };
      sonnet = {
        id = "claude-sonnet-5-5";
        name = "Claude Sonnet 5.5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1000000;
        maxOutput = 128000;
      };
      haiku = {
        id = "claude-haiku-5-5";
        name = "Claude Haiku 5.5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1000000;
        maxOutput = 128000;
      };
    };

    openai = {
      astra = {
        id = "gpt-6.2-astra";
        name = "GPT-6.2 Astra";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1050000;
        maxOutput = 128000;
      };
      sol = {
        id = "gpt-6.2-sol";
        name = "GPT-6.2 Sol";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1050000;
        maxOutput = 128000;
      };
      terra = {
        id = "gpt-6.1-terra";
        name = "GPT-6.1 Terra";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1050000;
        maxOutput = 128000;
      };
      luna = {
        id = "gpt-6-luna";
        name = "GPT-6 Luna";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        context = 1050000;
        maxOutput = 128000;
      };
    };

    furtherverse = {
      deepseek = {
        id = "deepseek-v4.1-flash";
        name = "DeepSeek V4.1 Flash";
        reasoning = true;
        input = [
          "text"
          "image"
        ];
        context = 1000000;
        maxOutput = 384000;
      };
      grok = {
        id = "grok-4.7";
        name = "Grok 4.7";
        reasoning = true;
        input = [
          "text"
          "image"
        ];
        context = 500000;
        maxOutput = 500000;
      };
      kimi = {
        id = "kimi-k3";
        name = "Kimi K3";
        reasoning = true;
        input = [
          "text"
          "image"
          "video"
        ];
        context = 1048576;
        maxOutput = 131072;
      };
    };
  };

  models = builtins.foldl' (
    acc: family: acc // builtins.mapAttrs (_nick: m: m // { provider = family; }) providers.${family}
  ) { } (builtins.attrNames providers);
in
{
  inherit gateway providers models;

  ref = nick: "${models.${nick}.provider}/${models.${nick}.id}";
}
