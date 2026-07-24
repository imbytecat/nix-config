# AI 网关 + 模型目录：Furtherverse 网关端点、provider 身份、密钥 env 名，以及跨 agent 引用的
# 模型 ID / 元数据的唯一真源。codex / opencode / claude-code / grok / pi / fish op-env 都是本目录的
# adapter，各自渲染成 TOML / JSON / env。改这里，各 agent 配置自动一致（同 modules/gateway/constants.nix）。
# 放 home 根这个中性位置：home/shell 与 home/dev/agents 平等 import，避免 shell→dev/agents 方向依赖。
let
  # 统一模型规格表：nick 为 key，每节点 { provider + id + 元数据 }，四家同一 schema（对称 keying）。
  # provider 标记上游家族，adapter 按需 byProvider 过滤投影；引用处只记 nick（models.<nick>.id 或
  # ref "<nick>"）。id 已确认（版本对，勿改）；name 为默认显示名可改；reasoning/input/output/
  # context/maxOutput 为占位，首次 switch 前填真实值。新增模型照抄一节点即可。
  models = {
    # Anthropic
    fable = {
      provider = "anthropic";
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
      provider = "anthropic";
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
      provider = "anthropic";
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
      provider = "anthropic";
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

    # OpenAI
    sol = {
      provider = "openai";
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
      provider = "openai";
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
      provider = "openai";
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

    # Google
    gemini = {
      provider = "google";
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

    # Furtherverse（网关聚合的第三方模型）
    glm = {
      provider = "furtherverse";
      id = "glm-5.2";
      name = "GLM-5.2";
      reasoning = true;
      input = [ "text" ];
      output = [ "text" ];
      context = 1000000;
      maxOutput = 131072;
    };
    grok = {
      provider = "furtherverse";
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
      provider = "furtherverse";
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
in
{
  # 网关端点（不含 /v1；各 adapter 自加 provider 版本后缀）。密钥永远走 env，不落字面量。
  endpoint = "https://ai-gateway.furtherverse.net";
  apiKeyEnv = "AI_GATEWAY_API_KEY";

  provider = {
    id = "furtherverse";
    name = "Furtherverse";
    npm = "@ai-sdk/openai-compatible";
  };

  inherit models;

  # 按 provider 家族过滤子集，adapter 投影用：byProvider "anthropic" → { fable opus sonnet haiku }。
  byProvider =
    p:
    let
      names = builtins.filter (n: models.${n}.provider == p) (builtins.attrNames models);
    in
    builtins.listToAttrs (
      map (n: {
        name = n;
        value = models.${n};
      }) names
    );

  # "provider/id" 限定名，opencode 等按 provider/model 引用的 adapter 用：ref "opus"
  # → "anthropic/claude-opus-4-8"。
  ref = nick: "${models.${nick}.provider}/${models.${nick}.id}";
}
