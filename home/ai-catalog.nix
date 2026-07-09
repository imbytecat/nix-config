# AI 网关 + 模型目录：Furtherverse 网关端点、provider 身份、密钥 env 名，以及跨 agent 引用的
# 模型 ID / 元数据的唯一真源。codex / opencode / claude-code / fish op-env 都是本目录的 adapter，
# 各自渲染成 TOML / JSON / env。改这里，各 agent 配置自动一致（同 modules/gateway/constants.nix）。
# 放 home 根这个中性位置：home/shell 与 home/dev/ai 平等 import，避免 shell→dev/ai 方向依赖。
{
  # 网关端点（不含 /v1；各 adapter 自加 provider 版本后缀）。密钥永远走 env，不落字面量。
  endpoint = "https://ai-gateway.furtherverse.net";
  apiKeyEnv = "AI_GATEWAY_API_KEY";

  provider = {
    id = "furtherverse";
    name = "Furtherverse";
    npm = "@ai-sdk/openai-compatible";
  };

  # 第一方模型规格表：nick 为 key，每节点 { id + 元数据 }，schema 同 furtherverseModels。
  # id 已确认（版本对，勿改）；name 为默认显示名可改；reasoning/input/output/context/maxOutput
  # 为占位，首次 switch 前填真实值。新增模型照抄一节点即可。opencode adapter 按 .id 投影成各
  # provider 的 models（与 furtherverse 的非对称 keying 见 docs/adr/0005）。
  anthropicModels = {
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
      id = "claude-opus-4-8";
      name = "Claude Opus 4.8";
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
  openaiModels = {
    gpt = {
      id = "gpt-5.5";
      name = "GPT-5.5";
      reasoning = true;
      input = [
        "text"
        "image"
        "pdf"
      ];
      output = [ "text" ];
      context = 256000;
      maxOutput = 128000;
    };
    gptMini = {
      id = "gpt-5.4-mini";
      name = "GPT-5.4 mini";
      reasoning = true;
      input = [
        "text"
        "image"
      ];
      output = [ "text" ];
      context = 400000;
      maxOutput = 128000;
    };
  };
  googleModels = {
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

  furtherverseModels = {
    "composer-2.5-fast" = {
      name = "Composer 2.5 (Fast)";
      reasoning = true;
      input = [
        "text"
        "image"
        "video"
      ];
      output = [ "text" ];
      context = 200000;
      maxOutput = 128000;
    };
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
    "glm-5.2" = {
      name = "GLM-5.2";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 131072;
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
