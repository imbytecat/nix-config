# Agent 遥测调研：Claude Code 与 Grok Build（2026-11-23）

## 结论

**Claude Code：保留全部 opt-out。依据是厂商立场，不是“遥测导致封号”已被证实。**

- Anthropic 官方只写了三类封号原因：反复违反 Usage Policy、从不支持的地区创建账号、违反服务条款。Safeguards 团队会做 “detection and monitoring”。隐私政策写明会收集设备标识与 IP，并用于防欺诈、防滥用。
- 官方没有任何文档把 Claude Code 的 device_id、feature-flag 拉取、错误上报或 attribution block 与封号挂钩。“遥测导致封号”只来自社区逆向与个案，**未证实**。
- 厂商唯一公开承认的客户端侧手段，是 2026-03 至 07 的系统提示词隐写水印。它会识别自定义 base URL、时区等信号，用于打击转售与蒸馏。Anthropic 工程师称这是一次实验，已经撤下，并说 “landed stronger mitigations”，但没说明具体是什么。这足以说明厂商愿意在客户端埋检测信号。
- 最宽的开关是 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`。它覆盖自动更新、遥测、错误上报、`/feedback`、release notes、可用性检查与 feature-flag 拉取。但文档按**枚举**定义，并点名排除 WebFetch 预检、官方 marketplace 自动注册和网关模型发现。它不是“未来所有非必要流量”的定义性兜底：已有两条新通道各配了独立开关。后续版本新增通道时，只能靠逐版核对文档。
- 按文档，本仓现有设置下仍会直连 Anthropic 的只有一条：内置 `claude-code-guide` agent 与预批准的 WebFetch 文档查询会访问 `code.claude.com`（及 `claude.com`）。触发条件是这类工具被调用，没有专门的开关。另有两处文档没写清 `/plugin` 的统计（`storage.googleapis.com`）和插件可执行文件下载（`downloads.claude.ai`）是否被总开关覆盖；本仓插件由 Nix 提供，见下文。
- **本仓应保留**：`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`、`CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1`、`skipWebFetchPreflight = true`、`CLAUDE_CODE_ATTRIBUTION_HEADER=0`，以及 `apiKeyHelper` 加网关 base URL。最后两项让 Remote Control、artifact、claude.ai connector 等依赖 claude.ai 身份的通道不可用。
- **可选补充**（一行 env，符合 AGENTS.md 的“一行 opt-out”）：`DISABLE_TELEMETRY=1`、`DISABLE_ERROR_REPORTING=1`、`CLAUDE_CODE_DISABLE_FEATURE_FLAGS=1`。当前它们被总开关覆盖，属冗余。只有当某个未来版本收窄 `NONESSENTIAL` 的范围时，它们才起作用 `[INFERENCE]`。

**Grok Build：“上传整个代码库”属实，有线上抓包与厂商回应佐证；该行为已在服务端关闭。**

- grok 0.2.93 会把**整个仓库加完整 git 历史**打成 git bundle，经 `POST /v1/storage` 上传到 xAI 的 GCS。上传与模型读了什么无关：被 deny 读取的文件、从未读过的 canary 文件和早已删除的提交都在 bundle 里。只有 `.gitignore` 里的文件被排除。0.2.99 与 0.2.101 二进制含同一套机制。
- 是否上传由服务端 `/v1/settings` 下发的开关决定（`trace_upload_enabled`、`disable_codebase_upload`）。非 ZDR 用户默认保留数据；关掉 “Improve the model” 也不能阻止上传（二手报道）。
- 2026-07-13/14，xAI 在服务端下发 `disable_codebase_upload: true` 与 `trace_upload_enabled: false`，`/v1/storage` 上传随即停止；`/v1/traces` 仍发出小请求。xAI 官方号回应时只指向 ZDR 与 `/privacy`；Musk 承诺删除此前上传的数据，无法独立核实。之后 CLI 以 Apache-2.0 开源（[xai-org/grok-build](https://github.com/xai-org/grok-build)）。
- **关闭开关**：`disable_codebase_upload` 是服务端字段，不是文档化的用户配置。当前开源代码里已没有这个字符串，本仓旧配置写的 `[harness] disable_codebase_upload = true` 也无证据生效 `[INFERENCE]`。现行源码中真正的本地开关如下：
  - 持久：`~/.grok/config.toml` 写 `[telemetry] trace_upload = false`，可再加 `[features] telemetry = false`。config 层优先于远程 flag。
  - 不可覆盖：在 `requirements.toml` pin `telemetry.trace_upload = false`。
  - 单进程：`GROK_TELEMETRY_TRACE_UPLOAD=0` 或 `DISABLE_TELEMETRY=1`。
  - `/privacy` 管的是账号级的“coding data 保留与训练”，按开源文档不影响 `trace_upload`。
- **本仓现状**：没有安装任何 Grok CLI。`grok.nix` 已在 2026-07-28 删除（`e384e14`）。T3 Code 用 `providerPackages = [ ]`，llm-agents wrapper 不会把自带的 `grok` 加进 PATH，本机 `which grok` 也找不到。catalog 里的 `grok`（`grok-4.7`）只是 furtherverse 网关上的一个模型 ID，由 pi/omp 经网关的 OpenAI 兼容接口调用，不经过 xAI CLI，也不涉及 `/v1/storage`。本机还残留旧的 `~/.grok/`（0.2.111，含 sessions 与 logs），可手动删除。

## Claude Code

引用约定：`DU` = [data-usage](https://code.claude.com/docs/en/data-usage.md)，`EV` = [env-vars](https://code.claude.com/docs/en/env-vars.md)，`NC` = [network-config](https://code.claude.com/docs/en/network-config.md)，`GW` = [llm-gateway-connect](https://code.claude.com/docs/en/llm-gateway-connect.md)，`GP` = [llm-gateway-protocol](https://code.claude.com/docs/en/llm-gateway-protocol.md)，均于 2026-11-23 抓取 `.md` 版本。本机 Claude Code 版本为 2.1.329。

### 1. 封号：厂商说法与社区说法

**一手（Anthropic）**

- 封号原因列为三类：“Repeated violations of our Usage Policy”“Account creation from an unsupported location”“Terms of Service violations”（[Safeguards warnings and appeals](https://support.claude.com/en/articles/8241253-safeguards-warnings-and-appeals)）。
- “Anthropic’s Safeguards Team implements detection and monitoring to enforce our Usage Policy”。规则还禁止用多账号规避检测、用新号绕过封禁（[Usage Policy](https://www.anthropic.com/legal/aup)）。
- 地区：未列出的国家或地区一律不支持，包括“physically located in an unsupported region”的使用，以及由不支持地区实体多数控股的公司；中国大陆不在列表中（[Supported Regions Policy](https://www.anthropic.com/legal/supported-regions)）。
- 隐私政策收集 “device or advertising identifiers”、IP 与派生位置、时区等，用途之一是 “prevent and investigate fraud, abuse, and violations of our Usage Policy”（[Privacy Policy](https://www.anthropic.com/legal/privacy)）。这是通用条款，没有点名 Claude Code 遥测。
- Consumer Terms 禁止除 API key 外的 “automated or non-human means” 访问（[Consumer Terms](https://www.anthropic.com/legal/consumer-terms)）。Claude Code 文档规定订阅 OAuth 只能用于 Anthropic 原生应用，并写明 “Anthropic reserves the right to take measures to enforce these restrictions … without prior notice”（[legal-and-compliance](https://code.claude.com/docs/en/legal-and-compliance.md)）。
- 厂商唯一承认的客户端检测手段是水印实验。Thariq Shihipar 称：“an experiment we launched in March that was meant to prevent account abuse from unauthorized resellers and protect against distillation … The team has landed stronger mitigations since then”。原帖在 [x.com/trq212](https://x.com/trq212/status/2072079729331777817)，转引自 [The Register 2026-07-01](https://www.theregister.com/ai-and-ml/2026/07/01/anthropic-is-removing-its-covert-code-for-catching-chinese-competitors/5265366)（二手转述一手声明）。
- 没有找到任何 Anthropic 文档或声明把 device_id、Statsig/GrowthBook、Sentry/Datadog 或 attribution block 与执法关联。

**二手 / 社区（未证实）**

- [jaysu66/claude-anti-ban](https://github.com/jaysu66/claude-anti-ban)（2026-05，1 star）：对 Windows `claude.exe` 的逆向。它称 `device_id = SHA256(MachineGuid)`，事件发往硬编码的 `api.anthropic.com/api/claude_code/metrics`，不受 `ANTHROPIC_BASE_URL` 影响。作者自述 4 个账号在同一台机器上被封，“>90%” 的再封率是作者自估。README 也承认风控规则在服务端，无法证明因果。
- [leeguoo：Claude 封号看三件事](https://blog.leeguoo.com/zh/posts/claude-account-ban-network-detection/)（2026-10-22 更新）称 GrowthBook 拉取请求带明文 `apiBaseUrlHost`（网关域名），旁边是设备 ID 与账号 ID（作者在 2.1.303 中观察到）。作者明确写道，这“不能证明哪个标识导致了封号”。
- [anthropics/claude-code#100182](https://github.com/anthropics/claude-code/issues/100182)（open）是用户报告：断网重连风暴后被以 “suspicious signals” 封号。没有 Anthropic 成员回复，只有 bot 和其他用户。
- [anthropics/claude-code#47558](https://github.com/anthropics/claude-code/issues/47558) 是文档 issue。它引用了 Boris Cherny 的话：“When you turn off telemetry we also disable experiment gates -- we do not call home when telemetry is off”（二手引用）。docs 补上 feature-flag 一节后，报告人于 2026-10-27 自行关闭了 issue。这说明关遥测也会停 flag 拉取，与封号无关。

### 2. 最宽的开关：`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`

- 语义按枚举定义：“disable nonessential network traffic: auto-updates, telemetry, error reporting, the `/feedback` command, Claude-drafted feedback, release notes, the PR and MR status badge checks, and availability checks such as the fast mode check”。它还会停止 plugin `command` source 的后台运行（EV 中 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` 一行）。
- 同一行写明 “Also disables feature-flag fetching”。也写明 “Official plugin marketplace auto-install isn't covered”和“Doesn't affect gateway model discovery”（EV 同一行）。
- DU 写道：“This variable doesn't affect the WebFetch check or official plugin marketplace auto-install; each has its own opt-out”（DU “Default behaviors by API provider”）。WebFetch 检查 “is not affected by `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`”（DU “WebFetch domain safety check”）。
- 只看是否设置：“Setting it to `0` or `false` still disables this traffic”（EV 同一行；EV 的 NOTE 把它列为只看是否设置的变量）。
- 它还关掉 session quality survey（DU “Session quality surveys”）和 artifact 工具（EV 中 `CLAUDE_CODE_ARTIFACT_COMMENTS` 一行：“when `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` has turned artifacts off”）。
- Datadog 两个 intake 主机（遥测与错误上报）“setting `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` disables both”（NC “Network access requirements” 下方说明）。
- 判断：文档没有承诺“凡是非必要流量都归它管”。已有两条后加的通道（WebFetch 预检、marketplace 自动注册）走独立开关，所以它不是对未来的兜底 `[INFERENCE]`。升级 Claude Code 时要复核 EV 这一行和 DU 的 “Default behaviors” 段。

### 3. 走网关时仍直连 Anthropic 的流量，逐项对照本仓设置

本仓设置（`modules/agents/claude-code.nix`）：`ANTHROPIC_BASE_URL` 指向 furtherverse 网关；`apiKeyHelper` 提供网关 key；`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`；`CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1`；`CLAUDE_CODE_ATTRIBUTION_HEADER=0`；`skipWebFetchPreflight = true`。本机 `~/.claude.json` 中没有 `oauthAccount`，即从未登录 claude.ai。

| 通道 | 文档依据 | 本仓状态 |
|---|---|---|
| 模型请求 | `ANTHROPIC_BASE_URL` “route requests through a proxy or gateway”（EV） | 走网关 |
| 使用指标（Datadog `http-intake.logs.us5.datadoghq.com`，旧版为 Statsig） | “Operational telemetry events, sent only when the CLI uses the Anthropic API directly”（NC 表）；DU 表中 “Claude API” 一列 “Default on”。文档没写清自定义 base URL 算不算 “directly”；社区称不受 base URL 影响（jaysu66，未证实） | 已关（NONESSENTIAL） |
| 错误上报（Datadog `browser-intake-us5-datadoghq.com`，旧版为 Sentry） | 仅在 “you sign in with a Claude Pro, Max, or Ultra subscription … connecting directly to the Claude API” 时开启（DU “Telemetry services”） | 不满足条件，且已关 |
| Feature flag（GrowthBook，`api.anthropic.com`） | NC 把 “feature flag fetches” 列在 `api.anthropic.com` 下；NONESSENTIAL 会关掉 flag 拉取（EV）。EV 还写道，只有 `ANTHROPIC_AUTH_TOKEN` 而无 API key 时，“Claude Code has no credential to fetch the flags with”。本仓 `apiKeyHelper` 提供的是 API key，没有总开关时可能带着网关 key 去拉 flag `[INFERENCE]` | 已关（NONESSENTIAL） |
| WebFetch 域名预检（`api.anthropic.com`，发送 hostname） | “runs regardless of which model provider you use and is not affected by `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`”（DU）；GW 与 GP 也重复了这一点 | 已关（`skipWebFetchPreflight`） |
| Fast mode 可用性检查（`api.anthropic.com`） | “goes to that host … never to the gateway”（NC）；“You set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, so Claude Code skips the check”（[fast-mode](https://code.claude.com/docs/en/fast-mode.md)） | 已关 |
| 自动更新 / 版本检查（`downloads.claude.ai`、`formulae.brew.sh`） | NONESSENTIAL 覆盖 auto-updates（EV） | 已关；Nix 管理版本 |
| `/feedback`、`/bug`、`/share`、Claude 起草的反馈、survey | NONESSENTIAL 覆盖（EV、DU） | 已关 |
| Release notes（`raw.githubusercontent.com`，GitHub） | NONESSENTIAL 覆盖 release notes（EV、NC） | 已关 |
| 官方 marketplace 自动注册（`github.com` clone） | 不受 NONESSENTIAL 覆盖，需要 `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`（EV、DU） | 已关 |
| Attribution block（客户端版本与对话指纹，放在 system prompt 开头） | “Any other upstream receives it as part of the prompt”；“not as a privacy control”（GP “System prompt attribution block”） | 已去掉；网关及其上游收不到指纹 |
| Remote Control | 在 `ANTHROPIC_BASE_URL` 指向非 Anthropic 主机或 `apiKeyHelper` 生效时不可用（EV、GW） | 不可用 |
| Artifact（策略从 `api.anthropic.com` 加载；内容来自 `*.frame.claudeusercontent.com`） | 需要 claude.ai 账号，“Sessions using an API key, gateway token … cannot publish”（[artifacts](https://code.claude.com/docs/en/artifacts.md) “Availability”）；NONESSENTIAL 也会关掉它 | 不可用 |
| claude.ai MCP connector（`mcp-proxy.anthropic.com`） | “enabled by default for claude.ai-authenticated users”（NC） | 未登录 claude.ai，不触发 |
| OAuth、登录（`claude.ai`、`platform.claude.com`） | 用于账号认证（NC）；“Claude Code keeps a saved claude.ai login on the machine but doesn't send it with those requests”（[llm-gateway](https://code.claude.com/docs/en/llm-gateway.md)） | 无 claude.ai 登录 |
| **文档查询（`code.claude.com`，以及 `claude.com`）** | “Claude Code documentation lookups by the built-in claude-code-guide agent and pre-approved WebFetch requests”（NC 表）；“pre-approved WebFetch documentation lookups also reach this host from the CLI”（NC `claude.com` 行） | **仍会发生**：调用这类工具时触发，没有专门开关 |
| `/plugin` 安装数与元数据（`storage.googleapis.com`） | “Plugin install counts and metadata shown in `/plugin`”（NC）；文档未说明 NONESSENTIAL 是否覆盖 | 未证实；只在打开 `/plugin` 时触发 |
| 插件可执行文件下载（`downloads.claude.ai`） | “Plugin executable downloads”（NC）；文档未说明 NONESSENTIAL 是否覆盖 | 本仓插件由 Nix 提供，预计不触发 `[INFERENCE]` |
| 网关模型发现 | 只请求网关，默认关闭（GP、EV） | 未开启 |

GW 对网关场景的总结：“Claude Code also sends nonessential background traffic outside the gateway path, to Anthropic and to third-party services such as GitHub … To turn that traffic off, set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`”；同时写明 WebFetch 预检不受影响（GW “Turn off traffic outside the gateway path”）。

### 4. 可选冗余开关（当前都被 NONESSENTIAL 覆盖）

- `DISABLE_TELEMETRY`：关闭遥测和 feature-flag 拉取，只看是否设置（EV）。
- `DISABLE_ERROR_REPORTING`：关闭错误上报，只看是否设置（EV）。
- `CLAUDE_CODE_DISABLE_FEATURE_FLAGS`：要求 v2.1.319+，本机 2.1.329 满足（EV）。
- `DISABLE_FEEDBACK_COMMAND`、`DISABLE_AUTOUPDATER`（EV）。

## Grok Build / Grok CLI

### 1. 上传了什么

- **线上抓包（原始一手，现已下线）**：cereblab 对 grok 0.2.93 做了 wire 分析并发布复现仓库 `cereblab/grok-build-exfil-repro`。2026-11-23 访问时，GitHub 仓库与 gist 均返回 404，只剩 archive 快照：[仓库 2026-09-06](http://web.archive.org/web/20260906103014/https://github.com/cereblab/grok-build-exfil-repro)、[gist 2026-11-05](http://web.archive.org/web/20261105135607/https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547)。本次没有解析快照正文。
- **独立复核（一手 wire 证据）**：[arafatkatze/grok-build-upload-receipts](https://github.com/arafatkatze/grok-build-upload-receipts)（2026-07-14）记录：
  - 上传的是完整 git bundle，`git bundle verify` 通过，clone 后能拿回被 deny 读取的 `tracked_secret.txt`。
  - 0.2.93 与 0.2.101 两个二进制均由 “X.AI Corporation (5Y6N3AJ54S)” 签名，内含 `grok-code-session-traces`、`after_codebase.tar.gz`、`disable_codebase_upload`、`xai-grok-shell/src/upload/*`。
  - 同一 0.2.93 二进制现在收到 `disable_codebase_upload: true`，不再发 `/v1/storage`；但仍有 `POST /v1/traces`（7,407 字节，204），尽管 `trace_upload_enabled: false`。
- **报道（二手）**：12 GB 仓库被分约 73 块上传，共 5.10 GiB；只有 `.gitignore` 里的文件被排除；删掉的已提交文件仍在 bundle 里（[The Hacker News](https://thehackernews.com/2026/07/grok-build-uploads-entire-git.html)）。即使用户让它不要打开文件，整个仓库及历史中的 secret 仍被上传，另有用户整个 home 目录被上传（[The Register 2026-07-14](https://www.theregister.com/ai-and-ml/2026/07/14/musk-promises-purge-after-grok-build-caught-sending-entire-repos-to-the-cloud/5271123)）。
- **0.2.99 拆解（二手，静态分析加本地日志）**：prompt tracing 开启时，每轮把仓库前后快照、会话内容、生效配置（含 `.claude/settings.json`）上传到 GCS bucket `grok-code-session-traces`，signed URL 来自 `code.grok.com`。文件过滤只按 `.gitignore` 和硬编码文件名。私有仓判断对 `unknown` 采取 fail-open，非 GitHub 远程也会上传（[Greywatch](https://greywatch.co/blog/grok-cli-repo-uploads)）。
- **默认开启**：上传由服务端设置控制，没有面向用户的开关（The Hacker News、The Register 引述 cereblab：“a silent global flag – disable_codebase_upload: true – that applies whether you opt in or out”）。关掉 “Improve the model” 时 `trace_upload_enabled` 仍为 true（[Breachnews](https://breachnews.com/research/grok-build-uploaded-entire-git-repositories-to-xai-storage-by-default/)，二手）。

### 2. xAI 回应与现状

- SpaceXAI 官方号：“For teams using zero data retention, no trace and code data is ever retained … If ZDR is disabled, the /privacy command is available in the CLI to disable data retention, which also deletes previously synced data”（[x.com/SpaceXAI](https://x.com/SpaceXAI/status/2076692402442846289)，经 The Register 转引）。
- Musk：“all user data that was uploaded to SpaceXAI before now will be completely and utterly deleted”（[x.com/elonmusk](https://x.com/elonmusk/status/2076739687658496209)，经 The Register 转引）。The Register 写道：“cannot independently verify whether SpaceXAI has deleted the data”。
- 2026-07-14，CLI 以 Apache-2.0 开源（`xai-org/grok-build`，仓库创建于 2026-07-14；[Simon Willison](https://simonwillison.net/2026/jul/15/grok-build/)）。
- 官方 docs 的企业网络页把 `storage.googleapis.com` 列为 “Fallback CDN for CLI binaries”，没有提及仓库上传（[docs.x.ai/build/enterprise](https://docs.x.ai/build/enterprise.md)）。官方 docs 中查不到 `disable_codebase_upload`。

### 3. 关闭开关（以开源源码为准）

源码版本为 [`xai-org/grok-build@2bdd1d6`](https://github.com/xai-org/grok-build/tree/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8)（2026-09-29，pager 1.0.45）。

- 全仓搜不到 `disable_codebase_upload`。远程设置结构里只有 `trace_upload_enabled`、`telemetry_enabled`、`telemetry_mode`（`crates/codegen/xai-grok-config/src/remote_settings.rs` 第 555–562 行）。
- `resolve_trace_upload` 按以下优先级取值（`crates/codegen/xai-grok-shell/src/agent/config.rs` 第 1883–1902 行；`crates/codegen/xai-grok-config/src/resolved.rs` 第 41 行：“the highest set tier wins: requirement, cli, env, config, managed, feature flag, default”）：
  1. `requirements.toml` pin；
  2. 环境变量 `GROK_TELEMETRY_TRACE_UPLOAD`；
  3. `config.toml` 中的 `[telemetry] trace_upload`；
  4. 远程 `trace_upload_enabled`，只在遥测开启时才读取；
  5. 默认值，等于“遥测是否开启”。
- 遥测模式按以下优先级取值（同文件第 1855–1881 行），无远程值时默认 Disabled：
  1. requirements pin；
  2. `DISABLE_TELEMETRY`；
  3. `GROK_TELEMETRY_ENABLED`；
  4. `[features] telemetry`；
  5. 远程 `telemetry_mode` 或 `telemetry_enabled`。
- 随包文档写的是 “`[telemetry] trace_upload` / `GROK_TELEMETRY_TRACE_UPLOAD` — session traces; follows telemetry when unset”；配置示例为 `trace_upload = false  # disable session/trace uploads`（`crates/codegen/xai-grok-pager/docs/user-guide/05-configuration.md` 第 565–580 行）。配置参考写的是 “`telemetry.trace_upload` | `boolean` | `pin` … Requirements pin beats user config”（`26-config-reference.md` 第 578 行）。
- `/privacy` 打开 “Coding data, retention, and training”。文档原文：“This setting doesn't touch `[features] telemetry`, `trace_upload`, or your external OTEL settings”（`04-slash-commands.md` 第 438–447 行）。cereblab 称其为 “a per-session retention toggle, not the switch that fixed this”（The Register 转引）。
- 结论：持久关闭写 `~/.grok/config.toml` 的 `[telemetry] trace_upload = false`（可再加 `[features] telemetry = false`）。不可覆盖的关闭在 `requirements.toml` 中 pin `telemetry.trace_upload`。按进程关闭用 `GROK_TELEMETRY_TRACE_UPLOAD=0` 或 `DISABLE_TELEMETRY=1`。`disable_codebase_upload` 只是服务端字段。
- 本机旁证：旧 `~/.grok/logs/unified.jsonl`（0.2.111，2026-07-24）有 16 条 `trace.upload.decision`，全部为 `uploads_enabled: false`、`upload_reason: "feature_off"`、`trace_upload_source: "config"`、`in_remote_trace_upload_enabled: null`。说明当时生效的是本地 `[telemetry] trace_upload = false`。

### 4. 本仓是否安装 Grok CLI

- 没有。`rg -n -i grok modules` 只命中 `modules/agents/_ai-catalog.nix` 第 126–128 行的 `furtherverse.grok`（`grok-4.7`）。它是 furtherverse 网关（`https://ai-gateway.furtherverse.net`）上的模型 ID，由 `_gateway-providers.nix` 交给 pi/omp，经网关调用。整条路径不涉及 xAI 的 CLI，也没有 `/v1/storage` 或 `code.grok.com`。网关后端是否转发到 xAI API 属于网关自身的数据政策，不在本文范围。
- 历史上曾经安装：`add8221`（2026-07-13）新增 `home/dev/agents/grok.nix`，写入 `features.telemetry = false`、`telemetry.trace_upload = false`、`harness.disable_codebase_upload = true`；`e384e14`（2026-07-28）删除了整个 grok agent。按上节源码，`harness.disable_codebase_upload` 不是已知的本地配置键 `[INFERENCE]`；真正起作用的是 `trace_upload = false`。
- `modules/agents/t3code.nix` 用 `providerPackages = [ ]` 覆盖 llm-agents 的 t3code。默认 wrapper 会把 `grok` 等 provider CLI 前置进 PATH（见 [11-18 调研](t3code-alma-2026-11-18.md)第 9 节）。本机 `which grok` 无结果。
- 残留：`~/.grok/` 仍在（`config.toml.bak`、`sessions/`、`logs/`、`agent_id`），不由 Nix 管理，可手动删除。

## 未能核实

- cereblab 原始仓库与 gist 已 404，只核对到 archive 快照的存在，没有读取快照正文。
- Datadog 遥测在 `ANTHROPIC_BASE_URL` 指向网关、且没有 NONESSENTIAL 时是否发送：文档写的是 “uses the Anthropic API directly”，含义未定义，本次没有抓包。
- `/plugin` 统计（`storage.googleapis.com`）与插件可执行文件下载（`downloads.claude.ai`）是否受 NONESSENTIAL 覆盖。
- 本次没有对 Claude Code 2.1.329 抓包，只依据文档。
- xAI 是否已删除数据；2026-07 之后服务端是否重新开启上传（开源客户端只在本地 config 未设时才读取远程值）。
