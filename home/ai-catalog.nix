# AI 网关与模型元数据真源，置于 home 根供 Codex、OMP、Pi、op-env 共享。
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
        id = "claude-fable-5";
        name = "Claude Fable 5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 1000000;
        maxOutput = 128000;
      };
      opus = {
        id = "claude-opus-5";
        name = "Claude Opus 5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 1000000;
        maxOutput = 128000;
      };
      sonnet = {
        id = "claude-sonnet-5";
        name = "Claude Sonnet 5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 1000000;
        maxOutput = 128000;
      };
      haiku = {
        id = "claude-haiku-4-5";
        name = "Claude Haiku 4.5";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 200000;
        maxOutput = 64000;
      };
    };

    openai = {
      sol = {
        id = "gpt-5.6-sol";
        name = "GPT-5.6 Sol";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 372000;
        maxOutput = 128000;
      };
      terra = {
        id = "gpt-5.6-terra";
        name = "GPT-5.6 Terra";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 372000;
        maxOutput = 128000;
      };
      luna = {
        id = "gpt-5.6-luna";
        name = "GPT-5.6 Luna";
        reasoning = true;
        input = [
          "text"
          "image"
          "pdf"
        ];
        output = [ "text" ];
        context = 372000;
        maxOutput = 128000;
      };
    };

    google = {
      gemini = {
        id = "gemini-3.1-pro-preview";
        name = "Gemini 3.1 Pro Preview";
        reasoning = true;
        input = [
          "text"
          "image"
          "video"
          "audio"
          "pdf"
        ];
        output = [ "text" ];
        context = 1048576;
        maxOutput = 65536;
      };
    };

    furtherverse = {
      ds = {
        id = "deepseek-v4-flash";
        name = "DeepSeek V4 Flash";
        reasoning = true;
        input = [ "text" ];
        output = [ "text" ];
        context = 1000000;
        maxOutput = 384000;
      };
      glm = {
        id = "glm-5.2";
        name = "GLM-5.2";
        reasoning = true;
        input = [ "text" ];
        output = [ "text" ];
        context = 1000000;
        maxOutput = 131072;
      };
      grok = {
        id = "grok-4.5";
        name = "Grok 4.5";
        reasoning = true;
        input = [
          "text"
          "image"
        ];
        output = [ "text" ];
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
        output = [ "text" ];
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
