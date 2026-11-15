# Orca 替代方案调研：herdr、T3 Code、Paseo 与同类工具（2026-11-15）

## 决策

用户补充的实际用法改变了权重：主要是多个工程并行 coding、偶尔用手机远程；更习惯 TUI（Orca 里 `omp` / Codex 的 chat 界面比 TUI 更容易出 bug）；不用多 agent 编排，worktree 很少用，浏览器无所谓。

因此改用 **herdr-app + herdr-core**，不用 herdr TUI：

- herdr-app 是 GUI 外壳，agent 仍以原生 TUI 跑在真实终端里，不是 chat 界面。
- `omp` 与 Codex 经 OSC 7501 原生上报状态，不向 `~/.omp`、`~/.codex` 注入任何东西。
- 手机 app 经 SSH 直连 herdr-core，可走 Tailscale，无中继、无账号；它不支持 herdr TUI。
- herdr TUI 上游没有宣布停更，官网 FAQ 只说 “keeps working”；但 2026-10-29 后没有提交，新功能都在 app 与 core。
- 代价：没有系统通知（[#120](https://github.com/herdrdev/herdr-app/issues/120)），主机重启后不自动 resume，Wayland 熄屏唤醒会崩窗口（[#1051](https://github.com/herdrdev/herdr-app/issues/1051)，core 里的终端不受影响），`dsh` 无状态。

## 调研结论（决策前）

**可以替代，前提是接受失去内置浏览器面板。** 推荐两台机器都改用 herdr TUI，Linux 补上 Ghostty 作宿主终端。浏览器面板或手机端不可放弃时，GUI 首选 Paseo，其次 T3 Code；两者都让 `omp` 以聊天线程运行，不再是原生 TUI。能在 GUI 里保留 `omp` TUI 的只有 Kandev，但它以看板为中心、社区小。

| 需求 | Orca 1.4.258 | herdr TUI 0.9.5 | herdr-app 0.1.15 | T3 Code 0.1.9 | Paseo 0.15.4 | agent-deck 1.16 |
|---|---|---|---|---|---|---|
| `omp` 原生 TUI + 状态 | ✅ 注入 extension | ✅ 需 integration | ✅ OSC 7501 | ⚠️ 仅 ACP 聊天 | ⚠️ 仅 RPC 聊天 | ✅ |
| Codex 状态 | ✅ 写 `hooks.json` | ✅ 屏幕识别 | ✅ OSC 7501 | ✅ app-server | ✅ app-server | ✅ `notify` |
| `dsh` 状态 | ⚠️ 依赖 `dsh-tui`，且 HM 只读冲突 | ❌ | ⚠️ 仅 `dsh-tui` | ⚠️ ACP | ⚠️ ACP，需先建 profile | ✅ |
| 系统通知 | ✅ | ✅ | ❌ | ✅ | ✅ | ⚠️ 状态栏 / web push |
| worktree 创建与清理 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 浏览器预览 | ✅ | ❌ | ❌ | ✅ | ✅ 仅桌面端 | ❌ |
| 关窗不停 | ✅ | ✅ | ✅ | ⚠️ 需 `t3 service install` | ⚠️ daemon，退出行为未核实 | ✅ tmux |
| 主机重启后 resume | ❌ | ✅ | ❌ | 未核实 | ⚠️ `omp` 恢复有 bug | 未核实 |
| 手机 | ✅ | ⚠️ SSH 客户端 | ✅ | ✅ | ✅ 免费 App | ⚠️ PWA |
| 写入 agent 配置 | `~/.omp`、`~/.dsh`、`~/.codex` | 可选 integration | 无 | 无（手动模式） | 无（终端 hook 默认关） | `config.toml` 的 `notify` |
| 遥测默认 | 开 | 无 | Nix 构建无 | 开 | 无 | 关 |
| llm-agents 缓存 | ✅ | ✅ | ✅ | ✅ | ⚠️ 桌面包需先更新 input | ✅ |
| 成熟度 | 每周约 5 版 | 约 8 个月；10-29 后无提交 | 约 1 个月，每日提交 | stable 约 1 个月 | 0.x，60 天 22 个 stable | 每 2 天约 1 版 |

理由：

1. 10 月以后 `omp` 主力工作已在 Mac 上、Orca 之外进行，Orca 的实际价值只剩 Linux 侧。
2. herdr TUI 覆盖全部硬需求，是候选中最成熟的终端型工具；无遥测代码，TOML 配置可由 HM 只读管理，llm-agents 包与上游最新一致。
3. Orca 向 `~/.omp`、`~/.dsh`、`~/.codex` 注入状态 hook；其中 `~/.dsh/cordis.patch.yml` 由 HM 只读链接，目前仍是 store 链接，Orca 的 `dsh` hook 从未写入。herdr-app 用 OSC 7501 完全不注入，但还太新。
4. 风险：herdr TUI 自 2026-10-29 无提交，开发重心转向 herdr-app。若 TUI 停滞，退路是 herdr-app（零注入）或 agent-deck（`omp`、`dsh`、Codex 一等支持，基于 tmux），两者都在 llm-agents。切换成本低，herdr TUI 的配置只有一份 TOML。
5. GUI 路线（Paseo、T3 Code）功能面更接近 Orca，但会把占 92% session 的 `omp` 从原生 TUI 换成聊天线程，接入层还有未修 bug；对以 TUI 为中心的用法是倒退。

## 方法与基线

- 本仓锁定 `llm-agents` 为 [`ee05b5ab`](https://github.com/numtide/llm-agents.nix/tree/ee05b5abb7c7f4af84a5ad5420f8a6e662774f2b)（2026-11-14），其中 Orca 为 1.4.258；候选工具的版本与平台以该 revision 的包定义为准，再对照上游最新发布。
- 使用画像只读取 Orca 本地状态（`orca-stats.json`、`profile-state.db` 的 settings 与 feature-interaction 计数、目录体积）以及 agent session 文件数量；未读取会话内容或密钥。Orca 遥测已关闭（`telemetry.optedIn=false`），这些计数只存在于本机。
- 上游事实来自各项目仓库、官方文档、发布页和包定义，链接写在对应段落；未安装或试运行任何候选工具。

## 实际使用画像

| 指标 | awesome-pc | awesome-macbook-air |
|---|---|---|
| Orca agent 活动区间 | 2026-07-29 → 2026-10-06 | 2026-10-29 安装，未添加 repo |
| Orca 内 agent 启动 | 827 次，约 263 agent-hours（7 月 98、8 月 662、9 月 0、10 月 67） | 0 |
| 同期整机 agent session | `omp` 432 个，Codex 37 个；Orca `defaultTuiAgent=omp` | — |
| 2026-10-07 之后的 `omp` session | 24 | 171（均在 Orca 之外） |
| repo / worktree | 8 个 repo、9 条 worktree 记录；`workspace-creation` 20–49、`workspace-cleanup` 10–19 | — |
| 内置浏览器 | `browser` 1000+（每次导航都计数，含 SPA 路由与 agent 驱动跳转）；`Partitions/orca-browser` 1.5 GB；repo quick command `bun run dev` | — |
| 终端 | `terminal-tabs` 500–999（手动建/关/改 tab 的次数）；native chat 关闭，agent 均以 TUI 运行 | — |
| agent 编排 | `agent-orchestration` 500–999（agent 调 `orca orchestration` RPC 的次数）；但 `orchestration.db` 只有一条迁移占位记录 | — |
| 移动端 | 配对过 2 台设备（`mobile-pairing` 5–9，`local-only`）；入口现已隐藏 | — |
| 未使用 | SSH target 0、automation 0、经 Orca 建 PR 0 | — |
| Codex 镜像目录 | `codex-runtime-home` 473 MB，其中 session 只来自 2026-07/08 | — |

结论性读数：

1. Orca 的实际价值集中在 Linux：多 worktree 下并排跑 `omp`、状态提示、内置浏览器预览 dev server。Codex 只占约 8% 的 session。
2. 10 月以后主力工作已经转到 Mac，并且不经过 Orca；awesome-pc 上 Orca 自 2026-10-06 起没有 agent 活动。
3. Linux 侧没有 Ghostty（`home/shell/ghostty.nix` 只在 Darwin 启用，且用 Homebrew cask），Orca 同时承担了 Linux 主终端的角色；换成终端型工具时要补一个 Linux 终端。
4. AGENTS.md 中 “Orca managed `CODEX_HOME` 有独立 trust store” 已过时：Orca ≥ 1.4.222 默认直接使用真实 `~/.codex`，镜像目录只剩旧数据（见下节）。

## Orca 基线（1.4.258）

下文 `O@v1.4.258/<path>` 指 [`stablyai/orca` v1.4.258](https://github.com/stablyai/orca/tree/v1.4.258) 中的文件。

- **发布**：MIT；最新 [v1.4.259](https://github.com/stablyai/orca/releases/tag/v1.4.259)（2026-11-14），近 3 个月 67 个稳定版，约每周 5 个；约 12.5 万 star。核心功能无需账号，手机 Relay 与 Artifacts 分享需要 Orca 账号（`O@v1.4.258/docs/site/content/docs/mobile.mdx`）。Electron 43.8.6。
- **浏览器**：每个 worktree 一个 Chromium 面板，终端链接可直接在面板打开；agent 用 `orca snapshot/click/fill` 驱动同一页面；Design Mode 把选中元素的 HTML、CSS、截图注入 agent 终端（`O@v1.4.258/docs/site/content/docs/browser/overview.mdx`、`browser/design-mode.mdx`）。
- **状态与通知**：working / needs input / done / blocked / idle 来自注入的 hook 或 extension，OSC 标题辅助；working → idle 时发系统通知（`O@v1.4.258/docs/site/content/docs/model/agents-sessions.mdx`、`notifications.mdx`）。
  - `omp`：Orca 向 `~/.omp/agent/extensions/` 写入 `orca-agent-status.ts`、`orca-prefill.ts`、`orca-titlebar-spinner.ts`（awesome-pc 上存在，日期 2026-10-06），把 `ask` 与工具审批识别为 needs input（`O@v1.4.258/src/main/pi/managed-extensions/titlebar-extension-service.ts`）。
  - `dsh`：启动命令是 `dsh-tui .`，hook 写入 `$DSH_HOME/cordis.patch.yml`（`O@v1.4.258/src/main/dsh/hook-settings.ts`）。本仓用 Home Manager 把这个文件链接成只读 store 文件，两者冲突 `[INFERENCE]`。
  - Codex：向 `~/.codex/hooks.json` 写 Orca hook，并把 approval hash 写入 `config.toml` 的 trust 段（`O@v1.4.258/src/main/codex/hooks/definitions/codex-hook-definition.ts`）。
- **`CODEX_HOME`**：自 [v1.4.222](https://github.com/stablyai/orca/releases/tag/v1.4.222) 起，默认 System 账号直接使用真实 `~/.codex`；只有 managed 账号、自定义 `CODEX_HOME` 或升级过渡期才进入 `codex-runtime-home` 镜像（`O@v1.4.258/src/main/codex-accounts/runtime-home-service-launch.ts`）。没有“完全不碰 `~/.codex`”的开关；关掉 `agentStatusHooksEnabled` 才停止写 hook，代价是失去 Codex 状态。
- **编排**：`orca orchestration worker-start/send/check/ask/reply` CLI，加上 Orca 安装给 agent 的 skill；`agent-orchestration` 计数统计的就是这些 RPC（`O@v1.4.258/src/main/runtime/rpc/runtime-feature-interaction.ts`）。awesome-pc 的 `orchestration.db` 没有 dispatch 或消息记录，旧版计数语义可能不同，因此无法确认编排真的被依赖。
- **持久化**：后台 daemon 持有 PTY；退出、崩溃、自动更新后可 warm-reattach，主机重启只恢复布局和 scrollback（`O@v1.4.258/docs/site/content/docs/model/session-restore.mdx`）。
- **手机**：iOS/Android companion 可看状态、回复、跑 quick command、commit；`local-only` 走 LAN，桌面关闭即断开（`O@v1.4.258/docs/site/content/docs/mobile.mdx`）。
- **遥测**：新安装默认开启（PostHog US），`DO_NOT_TRACK=1` 或 `ORCA_TELEMETRY_DISABLED=1` 关闭（`O@v1.4.258/docs/site/content/docs/telemetry.mdx`）。
- **Wayland / fcitx5**：仍 open 的有 [#42367](https://github.com/stablyai/orca/issues/42367)（KDE Wayland 原生模式下 chat 输入框切不出 fcitx5，XWayland 正常）和 [#33137](https://github.com/stablyai/orca/issues/33137)（Wayland 通知标题丢失、点击不聚焦）；终端内的 fcitx5 问题已陆续关闭。
- **打包**：已锁 llm-agents `orca` 1.4.258，Linux 用上游 deb，Darwin 用 arm64 zip，附带 computer-use 所需的 Python 运行时。

按使用量排序，替代品最难补齐的是：

1. 与 worktree 绑定的浏览器预览，以及 agent 驱动同一页面；
2. `omp` 的精确 needs-input 状态加系统通知；
3. daemon 持有 PTY、关窗不丢 agent；
4. worktree 创建与清理 UI；
5. 手机 companion（已试用、现隐藏）。

## herdr

herdr 有三条产品线，agent 互不共享：TUI 跑自己的 server；GUI `herdr-app` 与手机 app 都连接 daemon `herdr-core`，手机 app 不支持 TUI（[herdr.dev FAQ](https://herdr.dev/)、[mobile](https://herdr.dev/mobile/)）。三者免费、无账号；TUI、app、core 为 Apache-2.0，手机 app 未见公开源码。

开发重心已转向 app 与 core。官网 FAQ 称 app 是“基于 herdr-core 的新程序”，TUI 只写 “keeps working”；TUI 仓库 2026-10-29 后没有提交，并加了每月自动关闭无外部参与 stale issue 的 CI（`gh api repos/herdrdev/herdr/commits`，2026-11-15）。TUI 是否进入维护模式，上游没有明说 `[INFERENCE]`。

| | herdr TUI | herdr-app + herdr-core |
|---|---|---|
| 形态 | Rust 终端复用器，client/server | GPUI 原生 GUI（非 Electron）+ 无界面 daemon `hc`（OpenRPC） |
| 版本与成熟度 | [v0.9.5](https://github.com/herdrdev/herdr/releases/tag/v0.9.5)（2026-10-14），约 5.1 万 star，首版 2026-03-27；之后无新 stable，master 最后提交 2026-10-29 | app v0.1.15（2026-11-10）、core v0.1.21（2026-11-12），仓库建于 2026-10-16，每日都有提交 |
| 状态检测 | 屏幕识别 manifest 加可选 integration hook | 只读 OSC 7501，不读屏、不装 hook |
| `omp` | 需 integration，写入 `~/.omp/agent/extensions/herdr-omp-agent-state.ts` | 原生：`omp` 自己发 OSC 7501 |
| Codex | 屏幕识别；integration 只为 resume，会写 `~/.codex/hooks.json` | 原生：Codex 自 rust-v0.163.0 发 OSC 7501；不改 `CODEX_HOME` |
| `dsh` | 不识别，按普通终端处理 | 只识别第三方 `dsh-tui`；原生 `dsh` 无状态 |
| worktree | `herdr worktree create/open/remove`，默认 `~/.herdr/worktrees` | New / Open / Remove worktree 对话框 |
| 通知 | `[ui.toast] delivery = "system"`，Linux 走 `notify-send` | 只有应用内 toast 与提示音，系统通知 [#120](https://github.com/herdrdev/herdr-app/issues/120) 未做 |
| 持久化 | 关 client、断 SSH 不停；主机重启后经 integration 执行 `omp --resume=<id>`、`codex resume <id>` | 关窗不停；重启或 core 崩溃只开新 shell，不 resume |
| 手机 | 无，官方建议用 SSH 客户端 | iOS/Android app 经 SSH 直连 core，可走 Tailscale，无中继 |
| 浏览器预览 | 无 | 无，mod 不能用 web view |
| 配置 | `~/.config/herdr/config.toml`，HM 可只读管理（需 `onboarding = false`）；llm-agents 包自带 integration 文件 | `~/.config/herdr-app/settings.json` 等；app 会回写，HM 只能部分管理 |
| 遥测 | 源码无遥测；更新检查与远程 manifest 用 `[update] manifest_check = false` 关闭 | release 版默认开启；Nix 构建不发遥测、不自更新 |
| Linux 终端与 IME | 依赖宿主终端；awesome-pc 目前只有 Konsole，Kitty keyboard 协议支持未核实 | 自带 Ghostty VT 内核、原生 Wayland；Wayland 熄屏唤醒会崩 [#1051](https://github.com/herdrdev/herdr-app/issues/1051)，fcitx5 无报告也无测试 |
| 打包 | llm-agents `herdr` 0.9.5 = 上游最新；nixpkgs `herdr` 0.9.5 | llm-agents `herdr-app` 0.1.15、`herdr-core` 0.1.21，均 = 上游最新 |

来源：[herdr README v0.9.5](https://github.com/herdrdev/herdr/blob/v0.9.5/README.md)、[CHANGELOG v0.9.5](https://github.com/herdrdev/herdr/blob/v0.9.5/CHANGELOG.md)、[agents.mdx](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/docs/next/website/src/content/docs/agents.mdx)、[integrations.mdx](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/docs/next/website/src/content/docs/integrations.mdx)、[configuration.mdx](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/docs/next/website/src/content/docs/configuration.mdx)、[session-state.mdx](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/docs/next/website/src/content/docs/session-state.mdx)、[herdr-app README](https://github.com/herdrdev/herdr-app/blob/5216e6f9f8c0c281a65e09816c66e4319e671784/README.md)、[herdr-app defaults/AGENTS.md](https://github.com/herdrdev/herdr-app/blob/5216e6f9f8c0c281a65e09816c66e4319e671784/defaults/AGENTS.md)、[herdr-app security.md](https://github.com/herdrdev/herdr-app/blob/5216e6f9f8c0c281a65e09816c66e4319e671784/docs/security.md)、[herdr-core CONTRIBUTING](https://github.com/herdrdev/herdr-core/blob/c84d6e76156a6c2aac1da20efbe800f10acfe897/CONTRIBUTING.md)、[`dsh-tui` 的 OSC 7501](https://github.com/ccch1mneyyy/dsh-TUI/blob/77f2c515f269ba2537558cbc362f7ea2c44c7669/src/ink/termio/osc7501.ts)。

OSC 7501 是终端程序状态协议（[规范](https://www.superlogical.com/rex/docs/build/program-status)、[Mitchell Hashimoto 的说明](https://mitchellh.com/writing/program-status-osc7501)，2026-10-06）。本仓锁定的 `omp` 18.20.0 与 Codex 0.169.0 都会发出（[`omp` run-status.ts](https://github.com/can1357/oh-my-pi/blob/7c49c11aa5bbaf3f418406583096168ad5b8c6dc/packages/coding-agent/src/utils/run-status.ts)、[Codex terminal_program_status.rs](https://github.com/openai/codex/blob/ee344ca9458351a6ea102795fa73110ad3ede5dc/codex-rs/tui/src/terminal_program_status.rs)），所以 herdr-app 不需要往 `~/.omp`、`~/.codex` 注入任何东西就能拿到状态。这正是 Orca 依赖注入 hook/extension 的反面。

判断：herdr-app 是最接近“Orca 去掉浏览器”的替代，`omp` 与 Codex 原生有状态，不碰 `~/.codex`，Linux 上自带终端，手机直连。代价是只有约一个月历史，没有系统通知，重启后不 resume，`dsh` 无状态。herdr TUI 更成熟，系统通知与重启 resume 都有，但 Linux 上要先补宿主终端，且 `omp` 状态要装 integration。

## T3 Code

下文 `T3@v0.1.9/<path>` 指 [`pingdotgg/t3code` v0.1.9](https://github.com/pingdotgg/t3code/tree/v0.1.9) 中的文件。

- **形态**：本地 server `t3` 加 Electron 桌面端、Web、iOS、Android 前端；界面是聊天/线程式，不是终端复用器（[README](https://github.com/pingdotgg/t3code/blob/v0.1.9/README.md)）。MIT；relay 代码也在仓库内，但 T3 Connect 依赖托管的 `relay.t3.codes` 与 Clerk 登录。
- **成熟度**：README 原文 "We are very very early in this project. Expect bugs."；v0.1.0（2026-10-15）到 [v0.1.9](https://github.com/pingdotgg/t3code/releases/tag/v0.1.9)（2026-11-11）一个月 10 个 stable，另有每日多个 nightly；约 6.1 万 star、3.4k open issue。
- **Codex**：通过 `codex app-server` JSON-RPC 启动。手动登录模式使用进程的 `CODEX_HOME` 或默认 `~/.codex`，只按线程覆盖 T3 自己的 MCP server 等少数键（`T3@v0.1.9/apps/server/src/provider/Drivers/CodexDriver.ts`、`T3@v0.1.9/apps/server/src/orchestration-v2/Adapters/CodexAdapterV2.ts`），因此 HM 写的 gateway `model_provider` 与 hook trust 应直接生效 `[INFERENCE]`。“Connect with ChatGPT” 托管模式会改用 shadow home 并强制 `model_provider="openai_token_sharing"`（`T3@v0.1.9/apps/server/src/provider/CodexManagedRuntime.ts`），本仓不应使用。未信任的新 hook 会被静默跳过且没有审批 UI（[#5024](https://github.com/pingdotgg/t3code/issues/5024)）。
- **`omp` / `dsh`**：都走 ACP，聊天式受管。`omp` 以本地 ACP 命令 `omp acp` 接入，上游专门修过 OMP 兼容问题（[PR #33677](https://github.com/pingdotgg/t3code/pull/33677)）；`dsh` 按 [providers-acp.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/providers-acp.md) 以 `--profile`、`acp` 参数接入。ACP 下看不到 `omp` 原生 TUI 与扩展 widget；checkpoint 回滚会新开 ACP 会话。
- **原生 TUI**：只能在线程的 PTY 抽屉（Cmd+J）里手动运行，不被识别为 agent，没有状态与通知（[terminal.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/terminal.md)）。
- **worktree**：每线程可开 worktree，默认 `~/.t3/worktrees`，支持按不活跃、settle、合并或无提交自动清理，默认关闭（[project-settings.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/project-settings.md)）。
- **浏览器预览**：内置 headless Chrome 标签页，自动发现 localhost 端口，项目 action 可写进仓库 `t3.json`，能覆盖 `bun run dev` 用法；agent 可操作页面，人可接管（[remote-access.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/remote-access.md)）。隐藏预览标签不节流，13 个标签约 2.7 GB（[#15579](https://github.com/pingdotgg/t3code/issues/15579)）。
- **diff / PR**：按 turn 看 diff，线程内 commit、push、开 PR、review 与合并（[source-control.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/source-control.md)）。
- **远程与手机**：`t3 serve --lan`、`t3 serve --tailscale-serve`、桌面端托管 SSH 或 T3 Connect；原生 iOS/Android app。手机推送需要 T3 Connect 并开启 “Publish agent activity”，项目名和线程标题会发到 relay（[mobile-notifications.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/mobile-notifications.md)）。
- **Linux Wayland**：发布 AppImage/deb；桌面端没有加 `--enable-wayland-ime` 等开关，fcitx5 需自测 `[INFERENCE]`。仍 open：Wayland 剪贴板 [#31189](https://github.com/pingdotgg/t3code/issues/31189)、主进程 OOM [#21189](https://github.com/pingdotgg/t3code/issues/21189)、后台服务缺 `WAYLAND_DISPLAY` [#35736](https://github.com/pingdotgg/t3code/issues/35736)。
- **配置与遥测**：状态在 `~/.t3`（`T3CODE_HOME` 可改），`settings.json` 由 server 改写，不适合 HM 只读链接 `[INFERENCE]`；可声明的入口是 `/etc/t3code/policy.json` 与仓库 `t3.json`（[managed-policy.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/managed-policy.md)）。遥测**默认开启**，`T3CODE_TELEMETRY_ENABLED=false` 或 policy `limits.telemetry: false` 关闭，浏览器/移动端的 relay trace 关不掉（[telemetry.md](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/telemetry.md)）。
- **打包**：已锁 llm-agents 有 `t3code` / `t3code-desktop` 0.1.9（x86_64-linux、aarch64-linux、aarch64-darwin，源码构建，走 numtide cache）。其 wrapper 用 `--prefix PATH` 塞入 llm-agents 自带的 `codex` 等 CLI，会盖过 HM 的 `codex`；需 `override { providerPackages = [ ]; }` 或在 provider 设置里填 binary path。nixpkgs unstable 为 0.1.8；Homebrew cask `t3-code` 为 0.1.9。

判断：T3 Code 是功能面最接近 Orca 的 GUI 候选，Codex 手动模式直接读 HM 管理的 `~/.codex`；但它把 `omp` 变成 ACP 聊天线程、放弃原生 TUI，遥测默认开启，版本极新，Wayland 问题未清。

## Paseo

下文 `PS/<path>` 指 [`getpaseo/paseo@5a7a60ae`](https://github.com/getpaseo/paseo/tree/5a7a60ae50809d4dcbe2126b24501080fa61f3fe) 中的文件。

- **形态**：自托管 daemon 统一管理 agent；Electron 桌面、iOS/Android（Expo）、Web 与 CLI 都是客户端，不是终端复用器（[README](https://github.com/getpaseo/paseo#getting-started)）。Apache-2.0，relay 也开源（[paseo-relay](https://github.com/getpaseo/paseo-relay)）；手机推送经 Expo 的 `exp.host`。
- **成熟度**：约 2.4 万 star，仓库建于 2025-10-13；最新 stable v0.15.4（2026-11-10），60 天 22 个 stable，约 993 个 open issue。
- **接入方式**：全部走结构化协议。Codex 用 `codex app-server`，Pi/`omp` 用 `--mode rpc`，其余用 ACP（[providers](https://paseo.sh/docs/providers.md)）。工作区终端 tab 是普通 PTY，可手动跑任何 TUI；但只有 Claude、Codex、OpenCode 能拿到状态，且要开默认关闭的 `daemon.enableTerminalAgentHooks`，开启后会写 `~/.codex/hooks.json`（`PS/docs/terminal-activity.md`）。
- **`omp`**：内置 provider 默认关闭，需 `agents.providers.omp.enabled=true`；复用 Pi RPC，会导入 `~/.omp/agent/sessions`（[PR #1388](https://github.com/getpaseo/paseo/pull/1388)）。界面是聊天。仍 open：恢复会话失败 [#9722](https://github.com/getpaseo/paseo/issues/9722)、无法停止 Pi agent [#3749](https://github.com/getpaseo/paseo/issues/3749)。
- **Codex**：读 `CODEX_HOME`，未设则用 `~/.codex`（`PS/packages/server/src/server/agent/providers/codex-app-server-agent.ts` L674–675）；只有用户自建 Codex provider 时才注入 `paseo:<id>` 形式的 `model_provider`，所以 HM 的 gateway provider 与 hook trust 应直接生效 `[INFERENCE]`。
- **`dsh`**：可作为自定义 ACP provider，例如 `command: ["dsh", "--profile", "acp"]`（[custom-providers](https://paseo.sh/docs/custom-providers.md)）；本机 `~/.dsh/profiles` 只有 `web`，需先建 `acp` profile。
- **状态与通知**：结构化接入有运行、等待输入、完成三态；桌面系统通知与手机推送（[#7683](https://github.com/getpaseo/paseo/pull/7683)）；Linux 通知没有应用图标（[#8813](https://github.com/getpaseo/paseo/issues/8813)）。
- **worktree**：默认 `$PASEO_HOME/worktrees`；仓库 `paseo.json` 配 setup、teardown、services，`.worktreeinclude` 复制 `.env` 一类文件；最后一个工作区归档后执行 teardown 并删除（[worktrees](https://paseo.sh/docs/worktrees.md)）。
- **浏览器**：仅桌面端；agent 可经 MCP 打开 dev server、点击、截图（[browser](https://paseo.sh/docs/browser.md)）。
- **远程、手机、语音**：daemon 默认只听 `127.0.0.1:6767`，可走 SSH 隧道或 CLI `--host`；原生 App 免费，relay 默认关闭、开启后端到端加密，也可走 Tailscale（[security](https://paseo.sh/docs/security.md)、[connectivity](https://paseo.sh/docs/connectivity.md)）。语音默认本地 ONNX，默认识别模型只支持英语，中文需换 `whisper-base`（[voice](https://paseo.sh/docs/voice.md)）。
- **配置与遥测**：全局 `~/.paseo/config.json`（带 `$schema`），`paseo config set` 与设置界面都会改写它，HM 只读链接会让应用内改设置失败 `[INFERENCE]`；项目级 `paseo.json`。README 写明无遥测。
- **Linux Wayland**：llm-agents 桌面包用 nixpkgs `electron_44` 包装，未加 ozone/Wayland 参数；IBus 下新窗口收不到键盘输入（[#9652](https://github.com/getpaseo/paseo/issues/9652)），fcitx5 未测。
- **打包**：已锁 llm-agents 有 `paseo` 与 `paseo-desktop` 0.15.4，桌面包只给 Linux。该桌面包构建时没跑 `npm run postinstall`，很可能触发 React #130 启动崩溃（上游 [#7673](https://github.com/getpaseo/paseo/issues/7673)）；修复 [llm-agents#12318](https://github.com/numtide/llm-agents.nix/pull/12318)（`1b7ee581`）在本仓 lock 之后才合并，需先更新 input。首次启动还会从 Google 下载 React DevTools（[llm-agents#12276](https://github.com/numtide/llm-agents.nix/issues/12276)）。nixpkgs `paseo` 0.15.4；macOS 用 Homebrew cask `paseo` 0.15.4。

判断：Paseo 是 GUI 里最好的选择：无遥测、免费手机端、浏览器、worktree 生命周期完整，Codex 直接读 HM 的 `~/.codex`。但 `omp` 与 `dsh` 都变成聊天线程，`omp` 接入有未修 bug，0.x 迭代很快，锁定的 llm-agents 桌面包要先升级。

## Paseo / T3 Code 同类：自托管 daemon 加多端客户端

| 工具 | star / 最新版本 | `omp` / Codex / `dsh` | 接入方式 | 打包 | 备注 |
|---|---|---|---|---|---|
| [tiann/hapi](https://github.com/tiann/hapi) | 5 416 / v0.35.1（11-14） | ❌ / ✅ / ✅ | 包装官方 CLI；Codex 保留原生 TUI，同时经 app-server 共享会话；`dsh` 走 ACP（[agents.md](https://github.com/tiann/hapi/blob/main/docs/guide/agents.md)） | 仅 npm | 只做远程控制，无 worktree 与浏览器；原生 App 收费，PWA 免费 |
| [slopus/happy](https://github.com/slopus/happy) | 24 650 / CLI `happy` 1.2.6 | ACP 可能可接 `[INFERENCE]` / ✅ / ❌ | CLI 包装 Claude 与 Codex；桌面端 [happy-desktop](https://github.com/slopus/happy-desktop) 仍是 preview | llm-agents 与 nixpkgs `happy-coder` | 手机优先、端到端加密；无 worktree 与浏览器 |
| [kdlbs/kandev](https://github.com/kdlbs/kandev) | 1 131 / v0.101.0（11-11） | ✅ ACP 或 PTY passthrough / ✅ / ✅ 自定义 Terminal | ACP 加 PTY passthrough（[features](https://github.com/kdlbs/kandev/blob/main/docs/features.md)） | llm-agents 0.98.0，带 `ompSupport` | 唯一能在 GUI 中保留 `omp` TUI；看板为中心；AGPL-3.0；无遥测 |
| [CloudCLI / claudecodeui](https://github.com/siteboon/claudecodeui) | 14 623 / v1.37.8（11-07） | ❌ / ✅ / ❌ | Web UI | 无包 | 只是 Web 外壳，AGPL |
| [multica-ai/multica](https://github.com/multica-ai/multica) | 56 162 / v0.9.0（11-13） | 作为后台 CLI 运行环境 ✅ / ✅ / ✅ | 看板式异步派活 | llm-agents | 不是交互式工作台 |
| [openchamber/openchamber](https://github.com/openchamber/openchamber) | 12 921 / v2.7.2 | 仅 OpenCode | — | llm-agents 2.7.1 | 不适用 |
| [iOfficeAI/AionUi](https://github.com/iOfficeAI/AionUi) | 34 287 / v2.2.2（09-09） | ACP 聊天 | — | llm-agents（仅 Linux） | 偏办公，活跃度下降 |
| [coollabsio/jean](https://github.com/coollabsio/jean) | 1 421 / v1.0.16 | ❌（[#786](https://github.com/coollabsio/jean/issues/786)） / ✅ / ❌ | Tauri 桌面加 `jean-server` | 仅 Homebrew tap | — |
| [omnara-ai/omnara](https://github.com/omnara-ai/omnara) | 3 400 | — | 已转型为托管 agent 平台 | 无包 | 不再属于这一类 |
| [BloopAI/vibe-kanban](https://github.com/BloopAI/vibe-kanban) | 28 695 | — | — | — | README 宣布停止维护 |
| VibeTunnel | 4 708 / beta.18（07-11） | 任意 TUI，浏览器当终端 | — | 仅 Homebrew cask | 停滞 |

## 其他 GUI 工作台

- **Emdash**（[generalaction/emdash](https://github.com/generalaction/emdash)，约 6 千 star，v1.2.11）：交互最像 Orca，TUI 加 hooks 状态，内置 `omp`，有浏览器面板与可选 tmux 持久化（[providers](https://emdash.com/docs/providers.md)）。但 Nix 中没有包，会写 `~/.codex` hooks，PostHog 遥测默认开启（[telemetry](https://emdash.com/docs/telemetry.md)）。
- **Paradev（原 Superset）**（[ParadevAI/Paradev](https://github.com/ParadevAI/Paradev)，约 1.6 万 star，desktop-v2.0.8）：可在终端跑 `omp`，但 Linux 只有 “experimental and untested” 的 AppImage，手机与远程需 Pro，遥测默认开启，Nix 中没有包。
- **厂商应用**：Conductor 仅 macOS 且闭源；Codex 桌面应用已并入 ChatGPT 桌面应用，Linux 版为 preview（[OpenAI 说明](https://help.openai.com/en/articles/20001276-moving-to-the-new-chatgpt-desktop-app)）；Claude 桌面 Code 标签与 Cursor 3 Agents Window 只跑自家 agent。
- **停更或改名**：Crystal 已弃用并由 Nimbalyst 接替；Coder Mux 改名 Xum，使用自带 agent 循环；GitButler 0.20 移除 Claude Code GUI；opcode 停滞。

## 终端型同类

star、最新 release 与 60 天活跃度均为 2026-11-15 的 `gh api` 快照。

| 工具 | star | 最新 release | 现状 |
|---|---:|---|---|
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | 28 791 | v0.65.2.2（2026-10-27） | 活跃，**仅 macOS**，自带浏览器面板 |
| [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad) | 8 811 | v1.0.20（2026-08-20） | 60 天仅 1 次提交，近乎停滞；AGPL-3.0 |
| [Gaurav-Gosain/tuios](https://github.com/Gaurav-Gosain/tuios) | 6 532 | v0.13.1（2026-11-15） | 活跃；同时替代 zellij 与 herdr |
| [agent-of-empires](https://github.com/agent-of-empires/agent-of-empires) | 4 454 | v1.24.0（2026-11-15） | 活跃；不在 llm-agents / nixpkgs |
| [raine/workmux](https://github.com/raine/workmux) | 3 045 | v0.1.282（2026-11-10） | 活跃；挂在 tmux/zellij 上 |
| [kunchenguid/treehouse](https://github.com/kunchenguid/treehouse) | 1 942 | v3.1.8（2026-10-30） | 活跃；只做 worktree 池 |
| [standardagents/dmux](https://github.com/standardagents/dmux) | 1 819 | v5.11.1（2026-08-16） | 停滞约 3 个月 |
| [asheshgoplani/agent-deck](https://github.com/asheshgoplani/agent-deck) | 1 260 | v1.16.39（2026-11-14） | 非常活跃 |
| [kbwo/ccmanager](https://github.com/kbwo/ccmanager) | 1 279 | v4.4.11（2026-10-27） | 无 detach，内置列表没有 pi/`omp` |
| [marcus/sidecar](https://github.com/marcus/sidecar) | 1 093 | v1.17.1（2026-10-08） | 检测 manifest 每周同步自 herdr |
| [devflowinc/uzi](https://github.com/devflowinc/uzi) | 584 | v0.0.2（2025-06-03） | 已死 |

可行候选：

| | agent-deck | workmux + zj-radar | Agent of Empires |
|---|---|---|---|
| 底座 | Go TUI，基于 tmux，另有 web UI | 挂在现有 zellij 上；[zj-radar](https://github.com/marktoda/zj-radar) 是 zellij 侧栏插件 | Rust TUI，基于 tmux，另有 web/PWA |
| `omp` | 内置，含 resume/fork | 内置状态扩展；zj-radar 支持 `omp` | 只能自定义 agent 加 `status_rules` |
| `dsh` | 内置，识别 `DSH_HOME` | 无状态 | 只能自定义 |
| Codex 状态 | `config.toml` 中的 `notify = ["agent-deck", "codex-notify"]`，可直接写进 HM | 写 `hooks.json`，需重新授信 | 写 `$CODEX_HOME/hooks.json` |
| worktree | 创建、`worktree finish`（merge 并删除）、`cleanup`，带 setup/destruction 脚本 | `add` / `merge` 全生命周期 | 有，含多仓 workspace 与容器沙箱 |
| 通知与手机 | tmux 状态栏；`agent-deck web --push`，可配 Tailscale | 只有标签图标 | 浏览器 / iOS PWA push，web diff |
| 遥测 | opt-in，默认关 | 未核实 | opt-in，默认关 |
| 打包 | llm-agents `agent-deck` 1.16.38（上游 1.16.39） | llm-agents `workmux` 0.1.282；zj-radar 无包 | 仅上游 flake 与 Homebrew |

来源：agent-deck [tools.md](https://github.com/asheshgoplani/agent-deck/blob/843cba186506/docs/guide/tools.md)、[worktrees.md](https://github.com/asheshgoplani/agent-deck/blob/843cba186506/docs/guide/worktrees.md)、[remote-and-web.md](https://github.com/asheshgoplani/agent-deck/blob/843cba186506/docs/guide/remote-and-web.md)、[codex_hooks_cmd.go](https://github.com/asheshgoplani/agent-deck/blob/843cba186506/cmd/agent-deck/codex_hooks_cmd.go)；workmux [status-tracking.mdx](https://github.com/raine/workmux/blob/e76bb06daa21/docs/src/content/docs/guide/status-tracking.mdx)、[zellij.mdx](https://github.com/raine/workmux/blob/e76bb06daa21/docs/src/content/docs/guide/zellij.mdx)；AoE [README](https://github.com/agent-of-empires/agent-of-empires/blob/5b684602ef09/README.md)、[configuration.md](https://github.com/agent-of-empires/agent-of-empires/blob/5b684602ef09/docs/guides/configuration.md)、[telemetry.md](https://github.com/agent-of-empires/agent-of-empires/blob/5b684602ef09/docs/telemetry.md)。

- workmux 的 zellij 后端仍是实验性，要求 zellij ≥ 0.44.1，不支持 session 模式，≤ 0.45.1 有并发 bug（[zellij.mdx](https://github.com/raine/workmux/blob/e76bb06daa21/docs/src/content/docs/guide/zellij.mdx)）。
- 终端型方案都没有浏览器面板；cmux 有，但只能在 Mac 上补位，iOS 功能需付费 Pro。
- 这些工具都不另建 `CODEX_HOME`；写 `hooks.json` 的那类会让 HM 固定的 trust hash 需要再更新一次 `[INFERENCE]`。
- Linux 宿主终端：nixpkgs `ghostty` 1.4.0 修了 Wayland 下 IME 候选框跟随光标与 GTK 桌面通知（[1.4.0 release notes](https://ghostty.org/docs/install/release-notes/1-4-0)）；本身不提供 agent 状态、worktree 或 detach。

## 落地与后续

仓库改动：

- 新增两台桌面共用的 `modules/desktop/herdr.nix`，用 llm-agents 的 `herdr-app` 与 `herdr-core` 替换 Orca；Darwin 不用 Homebrew cask，因为 release 构建默认开遥测并自更新。
- `modules/shell/ghostty.nix` 在 Linux 由 HM 安装 nixpkgs `ghostty`，Darwin 仍用 cask，配置共用。
- `packages.x86_64-linux.orca` 改为 `herdr-app`，依赖更新工作流改为构建 `.#herdr-app .#wowtype`；README、AGENTS.md 与相关文档同步。

两台机器上已清理（未 switch）：

- Orca 写入的 `~/.codex/hooks.json`，以及 `config.toml` 中对应的 trust 条目（Mac 9 条、awesome-pc 8 条）。
- awesome-pc 的 `~/.omp/agent/extensions/orca-*.ts`。
- `~/.orca`、`~/.config/orca`（2.1 GB）、`~/Library/Application Support/orca` 与 `com.stablyai.orca` 偏好。Orca 镜像目录里的 37 个 Codex session 在 `~/.codex/sessions` 都有同名副本。
- 保留 `~/.local/share/orca`：那是 GNOME Orca 屏幕阅读器的目录。

switch 后要验证：

- herdr-app 在 KDE Wayland 下 fcitx5 能否输入中文，macOS 输入法是否正常。
- `omp` 与 Codex 的 working、needs you、done 状态是否出现在侧栏与手机 Inbox。
- 手机 app 能否经 Tailscale 连上 awesome-pc 与 Mac；两台都已开 sshd。

观察项：

- herdr-app 补上系统通知与重启 resume 之前，状态提醒只在窗口内和手机 app 打开时可见。
- herdr-app 不合用时，GUI 退路是 Paseo（需把 `llm-agents` 更新到 `1b7ee581` 之后）或 T3 Code，两者都会把 `omp` 变成聊天界面；TUI 退路是 herdr TUI 或 agent-deck。
