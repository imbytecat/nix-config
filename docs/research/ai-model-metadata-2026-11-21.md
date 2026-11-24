# AI 模型元数据：去哪查、catalog 记多少（2026-11-21）

> 2026-11-24 更新：Pi 对自定义模型会把缺少显式映射的 `max` 降到 `high`。Pi/OMP 现在用原生 provider 名接 Furtherverse，沿用内置模型元数据。DeepSeek 的原生 ID `deepseek-flash` 在网关返回 `model_not_found`，该网关别名与 DSH 才从 catalog 生成推理能力；catalog 使用 `flake.lock` 固定的 models.dev TOML，并覆盖 DeepSeek 在网关上无法关闭思考的差异。下文的选型结论保留调查当日的判断。

## 结论

- **模型本身的事实（上下文、输出上限、模态、推理档位、能否关思考、reasoning 字段名、价格）首选 models.dev。** 仓库 `github:anomalyco/models.dev`（默认分支 `dev`）每个模型一份 `providers/<provider>/models/<id>.toml`（`schema = 2`），文件头注释写明出处和实测日期；聚合 JSON 在 `https://models.dev/api.json`（6.8 MB，324 个 provider）。`_ai-catalog.nix` 的 11 个模型它全都有。
- **网关有没有这个模型、id 叫什么，只认网关 `GET /v1/models`。** models.dev 用厂商官方 id；网关可以不同，例如 DeepSeek 官方叫 `deepseek-flash`，网关叫 `deepseek-v4.1-flash`。
- **网关路由是否遵守推理参数，任何元数据源都不知道，只能实测。** 网关是 NewAPI（响应头 `x-new-api-version: v1.0.0-rc.51`），响应头 `x-magpie-provider` 显示真实上游。DeepSeek 目前走 `commandcode`，它不理会关思考参数（见下文）。
- **OMP 不需要 catalog 补元数据。** `omp models <provider> --json` 显示，OMP 按 id 从自带目录拿到了 catalog 全部 11 个模型的推理档位和价格（`pricingStatus: fixed`）。显式字段只有 DSH 和 Codex 用得上。
- **nixpkgs 有 `models-dev` 包，但不适合当数据源。** 它的版本是 `sdk-v0.0.5-unstable-2026-10-25`，没有 GPT-6.2 和 GPT-6.1 Terra；求值时读包输出还会变成 IFD。

## 来源

| 来源 | 提供什么 | 怎么查 | 局限 |
|---|---|---|---|
| models.dev 仓库 TOML | `limit`；`capabilities.reasoning`（`toggle`、`effort`、`default`）；`api.<wire>.compatibility.reasoning_field`；`cost`（含峰谷倍率、长上下文档） | `curl -s https://raw.githubusercontent.com/anomalyco/models.dev/dev/providers/deepseek/models/deepseek-flash.toml` | 描述官方 API，不代表网关路由 |
| models.dev `api.json` | 同一份数据的扁平版：`limit`、`modalities`、`reasoning_options`、`interleaved`、`cost` | `curl -s https://models.dev/api.json \| jq '.openai.models["gpt-6.2-astra"]'` | 同上 |
| 网关 `/v1/models` | 网关提供哪些 id | `curl -s -H "Authorization: Bearer $FURTHERVERSE_API_KEY" https://ai-gateway.furtherverse.net/v1/models \| jq -r '.data[].id'` | 只有 id |
| 网关响应头 | 请求实际转给了哪个上游 | `curl -sD- …/v1/chat/completions` 看 `x-magpie-provider`、`x-magpie-model` | 每个请求单独判断 |
| 厂商文档 | 参数语义，例如 GPT-6.2 Astra 拒绝 `reasoning_effort: none` | OpenAI 模型页的 markdown 版：`https://developers.openai.com/api/docs/models/<id>`；DeepSeek：`api-docs.deepseek.com/quick_start/pricing`、`/guides/thinking_mode` | 只能逐页读 |
| `omp models <provider> --json` | OMP 实际解析出的档位和价格 | `omp models furtherverse --json \| jq '.models[] \| {id, thinking, cost}'` | 只反映 OMP |
| NewAPI 后台 | 价格倍率从 models.dev 和 basellm 同步；模型元数据从 `basellm/llm-metadata` 同步 | 管理后台；源码 `controller/ratio_sync.go`、`controller/model_sync.go` | 服务网关计费和展示，不供 agent 配置用 |
| Artificial Analysis | 智力、延迟、每任务成本 | `artificialanalysis.ai/models/comparisons/<a>-vs-<b>` | 用于选型，不提供接线元数据 |

## catalog 与 models.dev 的差异（已对齐）

2026-11-21 起 catalog 的数值默认照 models.dev；网关确有不同时才偏离，并在条目旁注明原因。当天发现并改掉 3 处：

| nick | models.dev 条目 | 改动（旧 → 新） | 依据 |
|---|---|---|---|
| `deepseek` | `deepseek/deepseek-flash` | context 1000000 → 1048576；maxOutput 384000 → 393216 | DeepSeek `GET /models` 报 1048576 / 393216 |
| `kimi` | `moonshotai/kimi-k3` | maxOutput 131072 → 1048576 | Kimi Chat API：`max_completion_tokens` 最高 1048576 |
| `grok` | `xai/grok-4.7` | input 补 `pdf` | models.dev modalities |

其余 8 个本来一致。网关接受新上限：`max_tokens` 取 1048576（kimi）、393216（deepseek）、500000（grok）的请求都正常返回。

## models.dev 给出的推理选项

| nick | effort 档位 | 能否关思考 | reasoning 字段 |
|---|---|---|---|
| `fable`、`opus`、`sonnet` | low/medium/high/xhigh/max | 否 | — |
| `haiku` | low/medium/high/xhigh/max | 能（toggle） | — |
| `astra`、`sol` | low/medium/high/xhigh/max | 否 | — |
| `luna`、`terra` | none/low/medium/high/xhigh/max | 能（effort `none`） | — |
| `deepseek` | low/high/max | 能（toggle） | `reasoning_content` |
| `grok` | low/medium/high/xhigh | 否 | — |
| `kimi` | low/high/max | 否 | `reasoning_content` |

## 网关路由实测：DeepSeek

请求走 NewAPI → magpie → `commandcode`（`x-magpie-model: commandcode/deepseek/deepseek-v4.1-flash`）。

**思考关不掉。** 用同一个简单题目，每种写法测 3 次，reasoning token 都和默认值差不多：

| 写法 | reasoning tokens |
|---|---|
| 不带参数 | 68–139 |
| `thinking: {type: disabled}` | 67–104 |
| `reasoning_effort: none` | 79–126 |
| `chat_template_kwargs: {thinking: false}` | 68–86 |
| `chat_template_kwargs: {enable_thinking: false}` | 53–91 |
| `enable_thinking: false` | 56–90 |

`reasoning_effort` 取 `off`、`minimal`，`reasoning: {effort: none}`、`reasoning: {enabled: false}` 也都仍在思考（流式、带 tools 均测过）。DeepSeek 官方 API 上，`thinking.type=disabled`（官方文档）和 `reasoning_effort: none`（models.dev 文件注释）都能关掉思考，所以问题在上游路由，不在请求写法。

只测一次不可靠：简单题目即使开着思考，有时 reasoning 也接近 0；带 tools 的请求经常只直接发工具调用。必须对比多次采样。

**推理等级有效。** 用一道难题（非流式，`max_tokens` 60000，各发 5 次）：`low` 有 4 次在 15 分钟内答完，reasoning 为 19195–29182 token；`max` 5 次全部超过 15 分钟没有返回。所以 `reasoning_effort` 的 low/high/max 能用，只有关思考不行。max 档在难题上可能想很久，非流式请求要放宽超时。

要真正关掉思考，得在 NewAPI 后台把 `deepseek-v4.1-flash` 改走遵守 DeepSeek 参数的渠道，例如用 DeepSeek 渠道类型直连 `api.deepseek.com`。

复现：

```bash
curl -sS -D- https://ai-gateway.furtherverse.net/v1/chat/completions \
  -H "Authorization: Bearer $FURTHERVERSE_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"deepseek-v4.1-flash","thinking":{"type":"disabled"},"messages":[{"role":"user","content":"A train leaves at 09:47 and arrives at 13:12 the same day. How many minutes is the trip? Answer with just the number."}]}' \
  | grep -iE '^x-magpie|reasoning_tokens'
```

## catalog 该记多少

**现在不加字段。**

- OMP 自己已经知道所有模型的档位和价格。
- 真正读显式字段的只有 DSH（DeepSeek 的档位映射，3 行）和 Codex（`sol` 的上下文）。
- 这次的故障（off 不生效）出在路由行为上，元数据写得再细也修不了。

**以后要做时，折中方案：**

1. 加 flake input `models-dev = { url = "github:anomalyco/models.dev"; flake = false; }`。每个 catalog 模型加一个 `modelsDev = "deepseek/deepseek-flash"` 这样的引用，用 `builtins.fromTOML (builtins.readFile "${inputs.models-dev}/providers/<p>/models/<id>.toml")` 读取。已验证 Lix 能解析 `schema = 2` 的文件（`deepseek-flash.toml` 能读出 `limit`、`capabilities.reasoning`、`reasoning_field`）。这种做法只解析用到的文件，也不是 IFD。
2. `context`、`maxOutput`、`input`、`reasoning` 改从 TOML 派生，新增 `efforts`（取自 `capabilities.reasoning.effort`）和 `toggle`。网关与官方不同的地方（id、路由上限、路由不理会 toggle）用逐模型覆盖表达。
3. 投影：DSH 的 `reasoningEfforts` 取 effort 档位，只有 toggle 为真且路由实测遵守时才加 `off`；Codex 取上下文。OMP 的 models.yml 不动：OMP 的 `thinking` 字段需要按模型家族给出 `mode`，而它自带的规则已经正确。
4. 不做的事：
   - 不把各 harness 的 compat 开关（`thinkingFormat` 等）抄进 catalog。
   - 不在求值时读 `api.json`（不纯，而且 6.8 MB）。
   - 不用 nixpkgs 的 `models-dev`（版本滞后，还会变成 IFD）。
5. 风险：每周的自动更新也会更新 `models-dev`，上限和档位的变化会不经审阅直接合并。被引用的 TOML 消失时求值会失败，所以不会悄悄出错；如果想逐次审阅，就把它排除在每周更新之外。TOML 是仓库内部格式，上游换 schema 时读取逻辑要跟着改。

附带发现：OMP 的模型列表有两类噪声。一类是 `anthropic` provider 下也列出了网关的 20 个非 Claude 模型，价格为 unknown（推测来自 OMP 对网关 `/v1/models` 的发现）。另一类是 OMP 自带目录里网关不提供的条目（如 `claude-fable-5`），`paseo.nix` 的注释说的是这一类。
