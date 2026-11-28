# 手机派活调研：Paseo 与 `omp`（2026-11-20）

## 结论

桌前继续用 herdr TUI；手机派活另起一个常驻 daemon，两者互不干扰。

- **首选 Paseo**：`omp` 是一等 provider（`omp --mode rpc-ui`，专用实现 52 个文件）；手机 App 免费、无账号；推送不需要账号、不经 relay；daemon 无遥测；llm-agents 有包，上游 flake 自带 NixOS module。代价：`omp` 的 ask 模式审批有 bug，要用 full 模式（与现在 Codex、`dsh` 的“完全访问 + 不审批”一致）；推送正文（最后回复前 220 字符）经 Expo 与 APNs/FCM；会话记录的模型不可用时 resume 失败（[#9722](https://github.com/getpaseo/paseo/issues/9722)）。
- **其余不如这两者**：kandev 在 llm-agents 有包、推送可完全自托管，但 `omp` 的 `ask` 答不了，Web Push 还要 ≥0.99.0；herdr mobile 手机上仍是终端、无后台推送；`omp` 自带的 `/collab` 只能盯一个桌前已开的 TUI 会话，不能新建；Sesori 等 `omp` 专属 App 要么强制第三方 relay，要么只有 Android 且极新。
- **常驻主机用 awesome-pc**：`hosts/awesome-pc/default.nix` 已禁 suspend，PowerDevil 接电不自动睡眠。Mac 有意保留合盖睡眠，不适合当 host。
- **共同前提是密钥**：`FURTHERVERSE_API_KEY` 等只在 `~/.cache/op-env/env.fish`，且只由 fish 的 `interactiveShellInit` source（`modules/shell/fish.nix`）。systemd 拉起的 daemon 及其 spawn 的 `omp` 都拿不到，ExecStart 必须显式 source。

## 场景与评估维度

场景：人在外，家里电脑常开；手机上下发任务、并行跑多个、回答提问与审批、回来看结果。`omp` 必须好用，Codex 次之，`dsh` / `pi` 可选；不要求 herdr。

| # | 维度 | 说明 |
|---|---|---|
| R1 | 手机新建任务 | 选项目、选 agent 与模型、可开 worktree |
| R2 | 并行 | 多线程同时跑，互不阻塞 |
| R3 | 手机交互 | 回答 `ask`、审批、追加消息、中断、看 diff |
| R4 | 推送 | 完成 / 需要输入时提醒；经过谁、带什么内容 |
| R5 | `omp` 接入质量 | RPC / ACP；模型与 thinking 切换；扩展与 rule 是否生效 |
| R6 | 回桌接力 | 手机开的会话能否在桌前 `omp --resume` 继续 |
| R7 | 常驻部署 | Nix 包、systemd 服务、重启后恢复 |
| R8 | 隐私 | 遥测可声明式关闭；Tailscale 直连；relay 可选 |
| R9 | 不写 agent 配置 | `~/.omp`、`~/.codex`、`~/.dsh` 的只读配置不受影响 |

## Paseo 对各项需求的支持

| 维度 | Paseo 0.16.2 |
|---|---|
| R1 手机新建任务 | ✅ 项目或新 worktree，选 provider / 模型 / thinking |
| R2 并行 | ✅ 无 agent 数量上限 |
| R3 手机交互 | ✅ 提问、追问、图片、Stop、diff、归档 worktree；`omp` 的 ask 模式审批有 bug（[#10126](https://github.com/getpaseo/paseo/pull/10126) 只在 0.17 beta，[#10139](https://github.com/getpaseo/paseo/issues/10139) open） |
| R4 推送 | ✅ 无账号；daemon 直连 `exp.host`，经 Expo 与 APNs/FCM，正文是最后回复或工具输入前 220 字符；daemon 端关不掉 |
| R5 `omp` 接入 | 一等 provider，`omp --mode rpc-ui`，不依赖 `session_settled` |
| R6 回桌接力 | 会话是 `omp` 原生 JSONL，文档写明 `omp --resume` 能列出 |
| R7 常驻部署 | llm-agents `paseo`（master 0.16.1）；上游 `nixosModules.paseo`；`agents.resumeOnStartup` 可续跑 |
| R8 隐私 | 无遥测；relay 可选、E2E、可自建 |
| R9 不写 agent 配置 | ✅ 不写 `~/.omp`；Codex hooks 选项默认关 |
| 成熟度 | 0.x，60 天约 20 个 stable；iOS 最低 16.4 |

## Paseo 0.16.x

`PS/<path>` 指 [`getpaseo/paseo@v0.16.2`](https://github.com/getpaseo/paseo/tree/v0.16.2)（commit `2ee30f41`）；`LA/<path>` 指 [`numtide/llm-agents.nix@651289a8`](https://github.com/numtide/llm-agents.nix/tree/651289a86e658fd9252b96730c32e5f78285d108)（master，2026-11-20）。基线见 [11-15 调研](orca-alternatives-2026-11-15.md)的 Paseo 一节（0.15.4）。

### 版本与打包

[v0.16.0](https://github.com/getpaseo/paseo/releases/tag/v0.16.0)（11-16）、[v0.16.1](https://github.com/getpaseo/paseo/releases/tag/v0.16.1)（11-17）、[v0.16.2](https://github.com/getpaseo/paseo/releases/tag/v0.16.2)（11-18，Latest）、[v0.17.0-beta.1](https://github.com/getpaseo/paseo/releases/tag/v0.17.0-beta.1)（11-19，预发布）。

| 版本 | 与本场景相关的变化 |
|---|---|
| 0.16.0 | `omp` / Pi：null 可选参数的工具调用不再显示为未知工具（[#9506](https://github.com/getpaseo/paseo/pull/9506)）；导入的 `omp` 会话改存 session ID（[#8854](https://github.com/getpaseo/paseo/pull/8854)）；修复 Pi compaction 前的历史丢失（[#8523](https://github.com/getpaseo/paseo/pull/8523)）。重写移动端聊天（[#8717](https://github.com/getpaseo/paseo/pull/8717) 等）；worktree 归档可撤销，删除前检查未推送提交（[#8904](https://github.com/getpaseo/paseo/pull/8904)）；中断不再报 “already has an active run”（[#9537](https://github.com/getpaseo/paseo/pull/9537)）。 |
| 0.16.1 | 修复含 `/` 的模型名被截断（[#9836](https://github.com/getpaseo/paseo/pull/9836)、[#9823](https://github.com/getpaseo/paseo/pull/9823)），网关的 `provider/model` 形式依赖它；修复 daemon 重启后完成通知串回复（[#9846](https://github.com/getpaseo/paseo/pull/9846)）。 |
| 0.16.2 | 跟随 `omp` 自己改的 thinking（[#9841](https://github.com/getpaseo/paseo/pull/9841)）；修复第二次 Stop 后 agent 卡死（[#9774](https://github.com/getpaseo/paseo/pull/9774)）；修复归档时丢失 detached worktree 提交（[#10009](https://github.com/getpaseo/paseo/pull/10009)）。 |
| 0.17.0-beta.1 | 修复 `omp` 带 session/grant 选项的审批把“允许”当拒绝（[#10126](https://github.com/getpaseo/paseo/pull/10126)，11-18 合入 main，晚于 0.16.2 发布）；可从已有 worktree、分支或 PR 开工作区（[#10190](https://github.com/getpaseo/paseo/pull/10190)）。 |

新概念 Hub 可让 daemon 连 Paseo Cloud，由 GitHub、Slack、Discord 触发 agent；只有手动 `paseo hub connect` 才连接，连上后默认也无执行权限（`PS/docs/hub.md`）。本场景不需要。

| 包 | 版本 | 产物 | 平台 | 备注 |
|---|---|---|---|---|
| `paseo`（`LA/packages/paseo/package.nix`） | 0.16.1；本仓 lock 是 0.15.4 | `bin/paseo`（CLI）、`bin/paseo-server`（daemon 入口），nodejs_22 | x86_64-linux、aarch64-linux、aarch64-darwin | 源码构建，已跑 `npm run postinstall` |
| `paseo-desktop` | 0.16.1 | 包装 nixpkgs `electron_44` | 仅 Linux | React #130 已修（[llm-agents#12318](https://github.com/numtide/llm-agents.nix/pull/12318)）；unpackaged 运行，不自更新；首次启动仍从 Google 下载 React DevTools（[llm-agents#12276](https://github.com/numtide/llm-agents.nix/issues/12276) open） |

手机派活只需要 headless 的 `paseo`。

### `omp` provider

- 0.16 起 `omp` 是独立 provider（`PS/packages/server/src/server/agent/providers/omp/`），只和 Pi 共享 JSONL 子进程传输层（`PS/docs/providers.md` L151）。最低支持 `omp` 16.3.9（`omp/provider-config.ts` L13）。
- 启动：`omp --mode rpc-ui [--approval-mode yolo|write|always-ask] [--model M] [--thinking L] [--session <id>] [--append-system-prompt …]`（`omp/runtime.ts` L128–153）。
- 默认关闭，配置 `agents.providers.omp.enabled = true` 开启（`PS/packages/protocol/src/provider-manifest.ts` L251–257）；二进制默认从 PATH 找，可用 `command` 或 `OMP_COMMAND` 覆盖（`omp/cli-runtime.ts` L49）。
- 完成判定：`agent_end` 后调 `get_state`，确认 `isSettled`、无 pending async、未 streaming / compacting、队列为空才标 idle（`omp/agent.ts` L1183–1200、L1929–1946）。
- 模型与 thinking：启动参数设定，运行中可切换，并跟随 `omp` 发出的 `thinking_level_changed`（L1328、L1665–1678）。
- 审批与提问：full → `yolo`（默认）、write → `write`、ask → `always-ask`。`omp` 的 `extension_ui_request` 转成权限或提问卡片（`omp/rpc-ui-permission-mapper.ts`、`omp/question-ui.ts`）。ask 模式下两个缺陷：0.16.2 把带 session/grant 选项的“允许”当拒绝（[#10126](https://github.com/getpaseo/paseo/pull/10126) 只在 beta）；bash / edit / write 之外的工具审批允许后仍被当作 cancelled（[#10139](https://github.com/getpaseo/paseo/issues/10139) open）。
- 扩展与 rule：启动参数没有 `--no-extensions`，provider 目录内没有写 `~/.omp` 的代码；Paseo 自己的工具经 RPC 注册为 host tools（`PS/docs/providers.md` L162）。所以 ponytail 扩展与 caveman rule 应照常加载 `[INFERENCE]`。
- 会话：不传 `--no-session`，会话写在 `omp` 原生 JSONL 目录，Paseo 只存 session id，resume 时传 `--session <id>`（`omp/runtime.ts` L146–150）；导入读 `~/.omp/agent/sessions`（`omp/session-descriptor.ts` L172–205）。文档写明每次 rewind 新增一个会话文件，且 “`omp --resume` lists all of them”（`PS/docs/providers.md` L153–157）。同一会话不要两边同时写。
- 2026-11-10 后仍 open 的相关问题：[#9722](https://github.com/getpaseo/paseo/issues/9722)（日志是 `SessionModelRestoreError`，会话记录的模型无法恢复，“works in OMP TUI”）、[#3749](https://github.com/getpaseo/paseo/issues/3749)（Pi 无法 Stop，p1；部分修复见 [#9518](https://github.com/getpaseo/paseo/pull/9518)、[#9774](https://github.com/getpaseo/paseo/pull/9774)）、[#9711](https://github.com/getpaseo/paseo/issues/9711)（重载后计时错误）、[#9735](https://github.com/getpaseo/paseo/issues/9735)（时间线孤立的 “.”）、[#9914](https://github.com/getpaseo/paseo/issues/9914)（pi-subagents 恢复后仍显示 running）、[#10133](https://github.com/getpaseo/paseo/issues/10133)（Pi MCP 探测多起进程）、[#10145](https://github.com/getpaseo/paseo/issues/10145)（Pi 进程退出后不回收）。

### 手机 App

- iOS：[App Store](https://apps.apple.com/app/paseo-pocket-engineer/id6758887924)，免费，0.16.2，最低 iOS 16.4；Android：[Play](https://play.google.com/store/apps/details?id=sh.paseo) 与 GitHub APK；beta 走 [TestFlight](https://testflight.apple.com/join/Y5HpSQjJ)。f-droid.org 没有上架，但源码支持 F-Droid 构建。不需要 Paseo 账号（[why](https://paseo.sh/docs/why)）。
- README：“The mobile app is the full app, native on iOS and Android”（[README](https://github.com/getpaseo/paseo/blob/v0.16.2/README.md)）。

| 能力 | 状态 |
|---|---|
| 在项目或新 worktree 中建 agent | ✅；0.17 beta 增加已有 worktree、分支、PR |
| 选 provider、模型、thinking | ✅（[#8748](https://github.com/getpaseo/paseo/pull/8748)） |
| 追问、steer、图片 | ✅；纯文本 `omp` 模型把图片落盘后以路径传入（`PS/docs/providers.md` L141） |
| 回答权限与提问 | ✅；`omp` 审批缺陷见上 |
| Stop | ✅；相关 bug 见 #3749、#9774 |
| diff、归档 worktree | ✅（[#8907](https://github.com/getpaseo/paseo/pull/8907)、[#8904](https://github.com/getpaseo/paseo/pull/8904)） |
| 多主机 | ✅ Settings → Add host（[connectivity](https://paseo.sh/docs/connectivity)） |

### 连接与推送

- 直连：`config.json` 的 `daemon.listen` 或 `PASEO_LISTEN` 设为 Tailscale IP:6767；手机 Add host → Direct connection。认证用 `paseo daemon set-password`（bcrypt 写进 `config.json`）或 `PASEO_PASSWORD`；HTTP 用 Bearer，WS 首帧带密码，只有 `/api/health` 免认证（[security](https://paseo.sh/docs/security)、[configuration](https://paseo.sh/docs/configuration)）。直连没有 E2E，加密靠 Tailscale。
- Relay：可选，新装默认关；`paseo daemon pair` 询问后才开。daemon 的 ECDH 密钥对是信任锚，之后 NaCl box E2E，relay 只看到 IP、时间、大小、session id（[security](https://paseo.sh/docs/security)）。官方端点 `relay.paseo.sh:443`；relay 开源（[paseo-relay](https://github.com/getpaseo/paseo-relay)），可用 `PASEO_RELAY_ENDPOINT` 指向自建。
- 推送：App 用 Expo token 经 daemon 连接注册；daemon **直接** POST `https://exp.host/--/api/v2/push/send`（`PS/packages/server/src/server/push/push-service.ts` L24），再由 Expo 转 APNs/FCM。不经 relay，所以纯 Tailscale 直连也能推送，前提是 daemon 能出网 `[INFERENCE]`。只在 App 不在前台时发。
- 推送载荷：title 如 “Agent finished”；body 是最后一条 assistant 回复，或权限标题 / 描述 / 工具输入 JSON，截断到 220 字符（`NOTIFICATION_PREVIEW_LIMIT = 220`，`PS/packages/protocol/src/agent-attention-notification.ts`）；data 是 `{serverId, workspaceId, agentId, reason}`。
- daemon 没有关闭推送的配置项；只能在手机上拒绝通知权限，或用推送为空实现的 F-Droid 构建。推送 URL 写死，不能自建。

### 常驻 daemon

- 运行：`paseo daemon start`（受管实例），或前台 `paseo daemon run` / `paseo-server` 交给 supervisor；前台模式下 env 覆盖文件配置（[configuration](https://paseo.sh/docs/configuration)）。
- 上游 flake 导出 `nixosModules.paseo`（[`PS/nix/module.nix`](https://github.com/getpaseo/paseo/blob/v0.16.2/nix/module.nix)），选项含 `user`、`dataDir`、`listenAddress`、`port`、`relay.enable`、`environment`、`settings`、`inheritUserEnvironment`。注意：
  - `relay.enable` 默认 **true**，要直连须设 `false`（unit 加 `--no-relay`）；
  - `settings` 在 `preStart` 中以 `install -m 0600` 复制成可写的 `config.json`，每次启动覆盖运行时修改，所以 `set-password` 写进去的密码会被冲掉，密码应走 `PASEO_PASSWORD`；
  - `inheritUserEnvironment` 只补 PATH（含 `/etc/profiles/per-user/<user>/bin`），不带密钥环境变量；
  - 没有 launchd 方案。
- 状态目录 `$PASEO_HOME`（默认 `~/.paseo`）：`config.json`、日志、密钥对、worktrees、agent 数据、push token。`config.json` 须可写。
- 重启：默认不续跑；`agents.resumeOnStartup = true` 时，停机前 running 的 agent 会重开会话并发送 `Resume working.`，best-effort（`PS/docs/agent-lifecycle.md` L15–33）。idle agent 下次发 prompt 时以 `--session` 恢复；空闲 1 小时释放 runtime（`agents.idleRuntimeCleanup`）。
- 并发：没有 agent 数量上限，只有 Git 进程限流（`PASEO_GIT_*`）。

### Codex、`dsh`、`pi`

- Codex：`codex app-server`，读 `CODEX_HOME` 或 `~/.codex`；只有用户自建 Codex provider 时才注入 `model_provider`，HM 的网关配置与 `forced_login_method = "api"` 应直接生效 `[INFERENCE]`。只有默认关闭的终端 hooks 选项会写 `~/.codex/hooks.json`。
- `dsh`：自定义 ACP provider，`extends: "acp"` 加 `command: ["dsh", "--profile", "acp"]`，需先建 `acp` profile。
- `pi`：内置，`pi --mode rpc`；open bug 较多（#3749、#9452、#9571、#10145）。

### 遥测与自更新

| 组件 | 遥测 | 自更新 |
|---|---|---|
| daemon / CLI | 无。README 与 [why](https://paseo.sh/docs/why)：“no telemetry, tracking, or required Paseo account”；依赖中没有 sentry / posthog。外连只有 `exp.host` 推送、开启后的 relay 与 Hub、用户触发的 npm 插件安装、本地语音模型下载 | 无 |
| 手机 App | 依赖中没有分析或崩溃上报 SDK，也没有 `expo-updates`（无 OTA）；商店隐私标签未核对 | 跟随商店 |

## `omp` 侧（v18.20.3）

`OMP@<path>` 指 [`can1357/oh-my-pi@v18.20.3`](https://github.com/can1357/oh-my-pi/tree/90935366da0c368a437da4343ae748b03a2ffe97)（commit `90935366`），即本仓 llm-agents `733d5b0f` 打包的版本。上游已发布 v19.0.1（11-19），未核对。

### 会话与回桌接力

- `omp acp` 与 `omp --mode rpc` 都用 TUI 同一个 session manager，默认写 `~/.omp/agent/sessions/<cwd 编码>/`；ACP 客户端不能指定目录（`OMP@packages/coding-agent/src/main.ts:575-616`、`OMP@packages/coding-agent/src/session/session-manager.ts:4240-4258`）。所以 TUI 的 `--resume` / `--continue` 能直接接上手机开的会话；反向 ACP 的 `session/list` + `session/load`、RPC 的 `switch_session` / `open_session` 也能打开 TUI 会话（`OMP@packages/coding-agent/src/modes/acp/acp-agent.ts:1064-1124`、`OMP@packages/coding-agent/src/modes/rpc/rpc-mode.ts:921-952`）。
- ACP 与 RPC 都设 `PI_NO_TITLE=1`，这些会话没有自动标题（`main.ts:2034-2041`）。
- **会话 lease**：写会话的进程按 session id 持有 OS lease；别的活进程持有时，本进程第一次写入会把整份转录发布到新 sibling 文件、换新 id 继续写（[session.md](https://github.com/can1357/oh-my-pi/blob/90935366da0c368a437da4343ae748b03a2ffe97/docs/session.md)）。宿主的 `omp` 子进程还活着时回桌 `omp --resume`，得到的是内容完整的 fork。Paseo 空闲 1 小时回收子进程，之后再 resume 就是同一会话 `[INFERENCE]`；也可先在手机上关闭线程，或用 `omp session lease --json -- <id>` 查持有者。

### 只读 `config.yml`

- ACP 的 model / thinking / mode 与 RPC 的 `set_model` / `set_thinking_level` / 队列模式都只改会话内状态，不写 `config.yml`（`acp-agent.ts:2514-2574`、`rpc-mode.ts:2527-2564`、`OMP@packages/coding-agent/src/session/model-controls.ts:315-346`）。
- 例外：RPC `set_slow_mode` 在 Anthropic 模型上写全局设置。写只读 store 文件失败只记 `logger.warn`，不崩、不回错误帧（`OMP@packages/coding-agent/src/config/settings.ts:4015-4026`）；Nix 只读 `config.yml` 的相关修复 [#14622](https://github.com/can1357/oh-my-pi/pull/14622) 已含于 18.20.3。

### 扩展、rule、提问与审批

- `config.yml` 的 `extensions` 与 `~/.omp/agent/rules` 在 ACP 和 RPC 都加载（`OMP@packages/coding-agent/src/sdk.ts:1200-1215`、`2447-2465`），ponytail 与 caveman 照常生效。ACP 会话不读磁盘 `.mcp.json`，只用客户端给的 MCP（`main.ts:565-574`）。
- `ask` 工具：ACP 只在客户端声明 `elicitation.form` 时注册（`acp-agent.ts:810-941`）。RPC 只有 `--mode rpc-ui` 才注册（`main.ts:2409`）；Paseo 的 `omp` agent 以 `rpc-ui` 启动（`PS/packages/server/src/server/agent/providers/omp/agent.ts` L429、L2359、L2557，runtime 缺省才是 `rpc`）。
- 审批：ACP 走 `session/request_permission`。`config.yml` 未显式设 `tools.approvalMode: yolo` 时，ACP 会话仍对 `bash`、`edit`、`delete`、`move` 请求权限（`OMP@packages/coding-agent/src/session/acp-permission-gate.ts:7-20`、`session-tools.ts:1196-1237`）。RPC 走 `extension_ui_request` 的 select。
- plan：ACP 有 `plan` mode，计划批准走 elicitation，客户端不支持表单时自动批准（`acp-agent.ts:2534-2747`）；RPC 没有进入 plan mode 的命令 `[INFERENCE]`。
- 子 agent：ACP 只表现为 `task` 工具调用（`acp-event-mapper.ts:198-245`）；RPC 有 `set_subagent_subscription`、`get_subagents`、`cancel_subagent` 等（`rpc-mode.ts:2438-2526`）。
- 完成信号：RPC 只发 `session_settled`，“There is no Pi `agent_settled` frame”（[rpc.md](https://github.com/can1357/oh-my-pi/blob/90935366da0c368a437da4343ae748b03a2ffe97/docs/rpc.md)）。

### `omp` 自带的手机路径

- **`/collab` + `my.omp.sh` 网页客户端**：把正在运行的交互式 TUI 会话实时分享出去，浏览器可“添加到主屏幕”；能看流式转录与 subagent，能 prompt、打断，能回答 `ask` 与审批（[collab.md](https://github.com/can1357/oh-my-pi/blob/90935366da0c368a437da4343ae748b03a2ffe97/docs/collab.md)）。AES-256-GCM 端到端加密，key 只在 URL fragment。限制：一个房间一个会话，手机不能新建会话；没有推送（[#11609](https://github.com/can1357/oh-my-pi/issues/11609) open）；只限交互模式，ACP / RPC 会话不能 collab；生产 relay `wss://my.omp.sh` 不开源，仓库只有开发用替身 relay。适合在外盯一个桌前已开的 TUI 会话，不适合派新活。
- **`/share`**：一次性加密快照，只读。
- **Tern**（omp 作者公司 Stencil 的终端，含 iOS 客户端）：`omp` 在其中原生绘制，可经 Tailscale 连主机（[stencil.so/tern](https://stencil.so/tern)）；闭源、closed beta、需排 waitlist，Nix 无包。

## 其他候选

由 subagent 在 pinned 源码与文档上静态核查；`omp` 接入分级：RPC（`omp --mode rpc|rpc-ui`）、ACP（`omp acp`）、终端、无。

| 方案 | `omp` 接入 | 手机端 | 手机新建任务 | 回答 `ask` / 审批 | 推送与中转 | Nix | 判断 |
|---|---|---|---|---|---|---|---|
| [kandev](https://github.com/kdlbs/kandev) | ACP + PTY passthrough（[omp_acp.go](https://github.com/kdlbs/kandev/blob/2d93502c256780e1f3d9df4348dafbd97b584188/apps/backend/internal/agent/agents/omp_acp.go#L36-L110)） | 响应式 Web；PWA + Web Push 自 v0.99.0（[#4970](https://github.com/kdlbs/kandev/pull/4970)） | ✅ 看板建 task | 审批 ✅；SDK 无 elicitation，`omp` 的 `ask` 不注册，改用 kandev 自己的 MCP 提问工具 | 自托管；Web Push 用自生成 VAPID，载荷加密后经浏览器厂商；另有 Apprise（可接 ntfy）与 webhook | llm-agents 0.98.0，Web Push 要 ≥0.99.0；`ompSupport` 只把 `omp` 加进 PATH | 推送隐私最好；看板式，`ask` 体验降级 |
| agent-deck web | 终端（tmux） | 浏览器终端 + 看板（[remote-and-web.md](https://github.com/asheshgoplani/agent-deck/blob/d62c2898d623e5353392a06f9a77c19f97b33438/docs/guide/remote-and-web.md#L49-L121)） | ✅ | 只能在终端打字 | 自托管 VAPID Web Push，载荷含会话标题与路径 | llm-agents 1.16.39；自更新默认开，需 `auto_install=false` | 手机上仍是终端 |
| [herdr mobile](https://herdr.dev/mobile/)（现有） | 终端 + OSC 7501 Inbox | 原生 App：Inbox + 终端 | ⚠️ 新开终端手敲 `omp` | 在终端里答 | SSH 直连 core；无后台推送 | 已有 | 现状，手机上是 TUI |
| Alma mobile | 只读 `omp` 会话 | 原生 App，经 relay | ❌（[#280](https://github.com/yetone/alma-releases/issues/280) open） | 能看状态 | relay.alma.now | 无 | 不适合 |
| happy | 通用 ACP runner | 原生 App | ❌ daemon 只 spawn claude / codex / gemini 等（[run.ts](https://github.com/slopus/happy/blob/42d90b4c786b3bcff6111b363ff8fe3fbc42b4f2/packages/happy-cli/src/daemon/run.ts#L533-L556)） | 审批 ✅，`ask` ❌ | 必经 happy server（可自建）；推送明文含会话标题经 Expo；App 内置 PostHog | llm-agents `happy-coder` | 不适合 |
| hapi | 无；`pi` flavor 命令名写死（[agentLaunchCommand.ts](https://github.com/tiann/hapi/blob/4c430ceb62ea43e125485a37bb04b187f00d7685/cli/src/agent/agentLaunchCommand.ts#L8-L31)） | PWA | ❌ | — | — | 无 | 不适合 |
| multica | 一次性 `omp -p --mode json` / `--mode rpc` | Web 看板；iOS App 需自签 | ✅ 建 issue 指派 | ❌ UI 请求一律 cancelled（[pi_supplement.go](https://github.com/multica-ai/multica/blob/2fcb424b72b024f65161809081009063846ea44d/server/pkg/agent/pi_supplement.go#L298-L313)） | SaaS 或自建；自建 server 每日匿名快照默认开，`DO_NOT_TRACK=1` 关 | llm-agents 0.10.0（unfree，只有 CLI / daemon） | 异步派活，不能交互 |
| Sesori | ACP，声明 form elicitation | 原生 iOS / Android | ✅ | ✅ | 强制 `api.sesori.com` relay + 账号；推送明文含问题原文（[builder.dart](https://github.com/sesori-ai/sesori_apps_monorepo/blob/e14657f7fee6f3aaac6dc53fc48985c0d3bd4973/bridge/app/lib/src/push/push_notification_content_builder.dart#L42-L55)）；App 有 analytics | 无 | 功能贴合，隐私冲突 |
| [Rinai-R/omp-mobile](https://github.com/Rinai-R/omp-mobile)、[PinkCollab](https://github.com/3xian/PinkCollab) | RPC | 原生 Android | ✅ | ✅ | Tailscale 直连可行；PinkCollab 默认走 Tailscale Funnel 公网，需改 Serve | 无 | 仅 Android、个位数到十几 star，观察 |
| [fcying/omp-telegram](https://github.com/fcying/omp-telegram) 等 Telegram 桥 | RPC | Telegram | ✅ `/new <dir>` | 部分 | 明文经 Telegram | 无 | 小众 |
| Codex 官方 remote control | — | ChatGPT App | API key 登录被拒（[auth.rs](https://github.com/openai/codex/blob/rust-v0.169.0/codex-rs/app-server-transport/src/transport/remote_control/auth.rs#L187)） | — | OpenAI | — | 本仓用不上 |

补充：不靠任何宿主也能补推送，写一个 `omp` 扩展在 `agent_end` 或 `ask` 时推到自建 ntfy（[extensions.md](https://github.com/can1357/oh-my-pi/blob/90935366da0c368a437da4343ae748b03a2ffe97/docs/extensions.md)）`[INFERENCE]`。

## 落地要点

Paseo 放在 awesome-pc，与 herdr 并存。

**Paseo（推荐）**

- llm-agents 先升到带 `paseo` 0.16.2 的 revision（master 目前 0.16.1，缺 `omp` thinking 与 Stop 修复）。
- 服务：上游 `services.paseo` 要新增 flake input；功能只是一条 systemd unit，自写同样简单。要点：`--no-relay`；监听 Tailscale IP；`PASEO_PASSWORD` 走 op-env（仓库公开，bcrypt hash 也不进 git）；`settings` 开 `agents.providers.omp.enabled` 与 `agents.resumeOnStartup`。
- 密钥：ExecStart 先 `source ~/.cache/op-env/env.fish` 再 `exec paseo-server --no-relay`；`op-env-refresh` 后重启服务。
- 手机：Add host → Direct，填 Tailscale IP:6767 与密码；权限模式用 full。
- 回桌接力：`omp --resume` 选手机开的会话。Paseo 的 `omp` 子进程空闲 1 小时才回收，回收前 resume 会 fork 出新 id；赶时间就先在手机上 Stop 并归档。

## 方法

- 调研覆盖 Paseo 与 `omp` 侧（含广度扫描），只用一手来源（源码、文档、release、issue、包定义）；未安装、未运行任何候选。
- 主线程复核了决定性结论：Paseo `omp` agent 以 `rpc-ui` 启动（`agent.ts` L429、L2359、L2557）与 `agent_end` + `isSettled` 判定、推送直连 `exp.host` 与 220 字符截断、上游 module 的 `relay.enable` 默认值、#10139 / #9722 / #3749 为 open、#10126 合入晚于 0.16.2；`omp` v18.20.3 的 `loadSession: true`。
- 本仓事实：`hosts/awesome-pc/default.nix`（禁 suspend、PowerDevil）、`hosts/awesome-macbook-air/default.nix`（保留合盖睡眠）、`modules/shell/fish.nix`（op-env 缓存只在 interactive shell source）。

## 未能核实

- Paseo 与 `omp` 18.20.x 的端到端运行：turn 完成判定、扩展与 rule 加载、手机会话用 `omp --resume` 接续。
- Paseo：Tailscale-only 时 `exp.host` 推送确实送达；App Store / Play 隐私标签；上游 module 能否直接配 llm-agents 的包；各手机操作在小屏上的实际体验。
- `omp` v19（11-19 发布）对 ACP / RPC 有无改动；本仓锁定 18.20.x。
- `omp`：宿主 `session/close` 后 lease 是否立即释放；plain `--mode rpc` 下审批是否以 `extension_ui_request` 发出。
- 其他候选：kandev ≥0.99 的 Web Push 在 iOS 主屏 PWA 上是否可用；omp-mobile 用 `rpc` 还是 `rpc-ui`；Telegram 桥能否回答 `ask`。
