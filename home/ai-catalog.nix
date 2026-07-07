# AI 网关 + 模型目录：Furtherverse 网关端点、provider 身份、密钥 env 名，以及跨 agent 引用的
# 模型 ID / 元数据的唯一真源。codex / opencode / claude-code / fish op-env 都是本目录的 adapter，
# 各自渲染成 TOML / JSON / env。改这里，各 agent 配置自动一致（同 modules/gateway/constants.nix）。
# 放 home 根这个中性位置：home/shell 与 home/dev/ai 平等 import，避免 shell→dev/ai 方向依赖。
{
  # 网关端点（不含 /v1；各 adapter 自加 provider 版本后缀）。密钥永远走 env，不落字面量。
  endpoint = "https://ai-gateway.furtherverse.net";
  apiKeyEnv = "AI_GATEWAY_API_KEY";

  # Furtherverse OpenAI-compatible provider 身份（codex model_providers / opencode provider）
  provider = {
    id = "furtherverse";
    name = "Furtherverse";
    npm = "@ai-sdk/openai-compatible";
  };

  # 跨 agent 具名引用的外部模型（bump 版本改这一处）。存 bare id，adapter 按需加 provider 前缀。
  models = {
    opus = "claude-opus-4-8";
    sonnet = "claude-sonnet-4-6";
    haiku = "claude-haiku-4-5";
    gpt = "gpt-5.5";
    gptMini = "gpt-5.4-mini";
    gemini = "gemini-3.1-pro-preview";
  };

  # Furtherverse 自营模型目录：中性 per-model 元数据。opencode adapter 投影成自家
  # provider.models schema（name/reasoning/modalities/limit）；新增模型只改这一处。
  furtherverseModels = {
    "deepseek-v4-flash" = {
      name = "DeepSeek V4 Flash";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 384000;
    };
    "deepseek-v4-pro" = {
      name = "DeepSeek V4 Pro";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 384000;
    };
    "glm-5.1" = {
      name = "GLM-5.1";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 202752;
      maxOutput = 32768;
    };
    "kimi-k2.6" = {
      name = "Kimi K2.6";
      reasoning = true;
      input = [
        "text"
        "image"
        "video"
      ];
      output = [ "text" ];
      context = 262144;
      maxOutput = 65536;
    };
    "mimo-v2.5" = {
      name = "MiMo-V2.5";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1048576;
      maxOutput = 131072;
    };
    "mimo-v2.5-pro" = {
      name = "MiMo-V2.5-Pro";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1048576;
      maxOutput = 131072;
    };
    "minimax-m3" = {
      name = "MiniMax M3";
      reasoning = true;
      input = [
        "text"
        "image"
        "video"
      ];
      output = [ "text" ];
      context = 512000;
      maxOutput = 128000;
    };
    "qwen3.6-plus" = {
      name = "Qwen3.6 Plus";
      reasoning = true;
      input = [
        "text"
        "image"
        "video"
      ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 65536;
    };
    "qwen3.7-max" = {
      name = "Qwen3.7 Max";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 65536;
    };
  };
}
