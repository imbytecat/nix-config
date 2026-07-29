# AI 网关 + 模型目录：Furtherverse 网关实体（端点/密钥 env/身份）与跨 agent 引用的模型 ID /
# 元数据的唯一真源。codex / opencode / claude-code / omp / fish op-env 都是本目录的
# adapter，各自渲染成 TOML / JSON / YAML / env。改这里，各 agent 配置自动一致（同
# modules/gateway/constants.nix）。
# 放 home 根这个中性位置：home/shell 与 home/dev/agents 平等 import，避免 shell→dev/agents 方向依赖。
let
  # 网关实体：端点（不含 /v1；各 adapter 自加 provider 版本后缀）与密钥 env 名。密钥永远走 env，
  # 不落字面量。env 名用 FURTHERVERSE_ 品牌前缀而非通用的 AI_GATEWAY_*：后者被 Vercel AI SDK 的
  # gateway provider 自动读取，会把请求和密钥误路由到 Vercel。
  # provider 家族名（anthropic/openai/google/furtherverse）是共享词汇，各处直接
  # 字面量书写保持一致；显示名/npm SDK 包名之类 adapter 细节写死在各自 adapter，不进这里。
  gateway = {
    endpoint = "https://ai-gateway.furtherverse.net";
    apiKeyEnv = "FURTHERVERSE_API_KEY";
  };

  # 模型规格表：providers.<family>.<nick>，家族名只在这一层出现（模型节点不再重复 provider 字段）。
  # 每模型节点同一 schema。id 已确认（版本对，勿改）；name 为默认显示名可改；reasoning/input/
  # output/context/maxOutput 为占位，首次 switch 前填真实值。新增模型照抄一节点即可；
  # 扁平视图 models.<nick>（带 provider 字段）与 ref 由下方派生。
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

    # 网关聚合的第三方模型
    furtherverse = {
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

  # 扁平视图：models.<nick> = 节点 + provider 字段（nick 全局唯一，由上表保证）。
  models = builtins.foldl' (
    acc: family: acc // builtins.mapAttrs (_nick: m: m // { provider = family; }) providers.${family}
  ) { } (builtins.attrNames providers);
in
{
  inherit gateway providers models;

  # "provider/id" 限定名，opencode/omp 等按 provider/model 引用的 adapter 用：ref "opus"
  # → "anthropic/claude-opus-4-8"。
  ref = nick: "${models.${nick}.provider}/${models.${nick}.id}";
}
