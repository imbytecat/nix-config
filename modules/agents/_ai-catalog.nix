# 网关身份、模型别名和路由差异在这里维护；模型能力来自 flake.lock 固定的 models.dev。
{ lib, modelsDev }:
let
  gateway = {
    # 避免 AI_GATEWAY_*：Vercel AI SDK 会自动读取并误路由。
    endpoint = "https://ai-gateway.furtherverse.net";
    apiKeyEnv = "FURTHERVERSE_API_KEY";
  };

  readModelFile =
    path:
    let
      data = builtins.fromTOML (builtins.readFile "${modelsDev}/${path}.toml");
    in
    assert lib.assertMsg (data.schema == 2) "models.dev: unsupported schema in ${path}";
    data;

  model =
    vendor: id:
    let
      path = "providers/${vendor}/models/${id}";
      entry = readModelFile path;
      base = if entry ? base_model then readModelFile "models/${entry.base_model}" else { };
      # provider 的 limit、capabilities 等覆盖基础模型；如上游开始裁掉继承字段，升级时需复核。
      meta =
        assert lib.assertMsg (
          (entry.base_model_omit or [ ]) == [ ]
        ) "models.dev: review base_model_omit in ${path}";
        lib.recursiveUpdate base entry;
      reasoning = meta.capabilities.reasoning;
      efforts = reasoning.effort or [ ];
      modality =
        mime: if mime == "application/pdf" then "pdf" else builtins.head (lib.splitString "/" mime);
    in
    {
      inherit id;
      nativeId = id;
      inherit (meta) name;
      input = lib.unique (map modality meta.modalities.input);
      context = meta.limit.context;
      maxOutput = meta.limit.output;
      reasoning = reasoning.supported;
      # none 表示关闭思考，与 low/high 等强度分开，交给各客户端编码。
      efforts = lib.remove "none" efforts;
      canDisableThinking = (reasoning.toggle or false) || builtins.elem "none" efforts;
    };

  providers = {
    anthropic = {
      fable = model "anthropic" "claude-fable-5-2";
      opus = model "anthropic" "claude-opus-5-5";
      sonnet = model "anthropic" "claude-sonnet-5-5";
      haiku = model "anthropic" "claude-haiku-5-5";
    };
    openai = {
      astra = model "openai" "gpt-6.2-astra";
      sol = model "openai" "gpt-6.2-sol";
      terra = model "openai" "gpt-6.1-terra";
      luna = model "openai" "gpt-6-luna";
    };
    deepseek.deepseek = model "deepseek" "deepseek-flash" // {
      id = "deepseek-v4.1-flash";
      name = "DeepSeek V4.1 Flash";
      # 网关的 commandcode 路由忽略关闭思考的参数（2026-11-21 实测）。
      canDisableThinking = false;
    };
    xai.grok = model "xai" "grok-4.7";
    moonshotai.kimi = model "moonshotai" "kimi-k3";
  };

  models = builtins.foldl' (
    acc: family: acc // builtins.mapAttrs (_nick: m: m // { provider = family; }) providers.${family}
  ) { } (builtins.attrNames providers);
in
{
  inherit gateway providers models;

  effortFor =
    m: effort:
    assert lib.assertMsg (builtins.elem effort m.efforts)
      "${m.id}: unsupported default reasoning effort '${effort}'";
    effort;

  ref = nick: "${models.${nick}.provider}/${models.${nick}.id}";
}
