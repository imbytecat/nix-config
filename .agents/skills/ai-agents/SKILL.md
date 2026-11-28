---
name: ai-agents
description: "本仓 AI agent 配置（Codex、Claude Code、OMP、Pi、Paseo）与 Furtherverse 网关、模型 catalog、behavior bundle 的约定。修改 modules/agents/*、模型或网关、ponytail/caveman/共享 skills 前先读。触发词: codex, claude code, omp, pi, paseo, catalog, gateway, ponytail, caveman, skills。"
---

# AI agent 配置

## 结构

两条轴：

- **behavior bundle**（`_bundles/`）：跨 agent 的行为包。每个 bundle 按 agent 分键（`codex` / `claude` / `omp` / `skills`），`_bundles/default.nix` 按键取列。pin 相关的打包、OMP 文件和 skill 取舍只在各自 bundle 改。
- **agent 映射**：`codex.nix`、`claude-code.nix`、`omp.nix`、`pi.nix`、`paseo.nix`、`skills.nix` 只把 catalog 与 bundle 映射到各客户端的原生配置。

`agents/default.nix` 经 `_module.args` 向 HM `workstation` 注入：

| 参数 | 内容 |
|------|------|
| `aiCatalog` | `_ai-catalog.nix`：网关 endpoint、provider 身份、模型 ID 与元数据的唯一来源 |
| `gatewayProviders` | `_gateway-providers.nix`：catalog → 网关 provider 的投影（`mkProviders`），OMP、Pi 共用 |
| `agentBundles` | 按 agent 分列的 bundle |
| `llmAgents` | `inputs.llm-agents.packages.<system>`。不加 overlay、不 follows 本仓 nixpkgs，否则 miss `cache.numtide.com` |

同一角色装 Node.js 供插件 hooks 使用。网关密钥等会话 env 来自 `modules/secrets.nix`，HM 里是 `sessionEnvFile` 参数。

## Catalog

- 模型位于 `providers.<family>.<nick>`，family 用客户端内置的厂商标识（anthropic、openai、deepseek、xai、moonshotai）。映射文件经扁平的 `models.<nick>`（含 `provider`）、`ref "<nick>"`（→ `provider/id`）或 `providers.<family>` 消费。模型与 endpoint 只在 catalog 改。
- 新增模型时引用 `models-dev` input 的厂商与条目 ID；catalog 合并 provider 与 base model 的元数据，网关 ID、显示名或实测的能力差异在条目旁覆盖。
- Pi 与 OMP 的原生模型继承客户端内置元数据，只有网关 ID 与原生 ID 不同时才生成额外条目。Pi 的 `thinkingLevelMap` 从 catalog 生成；各 agent 自选默认档位，用 `effortFor` 校验。
- 模型可用性只认网关 `/v1/models`；网关路由是否遵守推理参数只能实测。来源与命令见 `docs/research/ai-model-metadata-2026-11-21.md`。

## 各客户端

### Codex（`codex.nix`）

- 内置 `openai` provider，`openai_base_url` 指向网关。TUI 与 app-server 都读原生登录文件。SOPS 解密后以工作站用户同步网关登录凭据。
- `config.toml` 必须可写，Codex 要持久化项目与 hook 信任：关掉 HM 的只读 symlink，激活时用 `mkImpureConfigMerger` 把静态配置合并进去。
- 插件经 HM marketplace/cache 加载。Codex 0.146 只把真实目录算 installed，`materializeCodexPlugins` 在 link 后把 store symlink 落成实体目录。
- hook 信任：Codex 把信任同时钉在声明 hash 与整个插件目录的内容 hash 上，插件或 Codex 一更新，手钉的 hash 就失效，hook 静默报 `Failed`（曾因此长期没生效）。Codex 没有持久的“信任全部”开关：`--dangerously-bypass-hook-trust` 只管单次调用，`app-server` 也不认。所以不钉 hash，`trustCodexHooks` 经 `codex app-server` 的 `hooks/list` + `config/batchWrite`（与 TUI 审批同一写法）信任 `$HOME` 下列出的全部 hook。Codex 本就是 `never` 审批 + 完全访问，这一步不扩大权限；项目自带 `.codex/` 的 hook 仍按项目审批。

### Claude Code（`claude-code.nix`）

- 用户级 `permissions.defaultMode = "bypassPermissions"` 覆盖独立 CLI；`enableAllProjectMcpServers` 单独批准项目 `.mcp.json`。首次进入新仓库的交互式工作区信任独立于工具审批。
- HM `programs.claude-code`。bundle 的 `claude.plugin` 是自带 `.claude-plugin/` 的上游仓库根，整目录 link 成 personal plugin，hooks/skills/commands 随 manifest 生效；`claude.files` 放 bundle 额外需要的文件。
- 模型只经 settings `env` 的 `ANTHROPIC_DEFAULT_{FABLE,OPUS,SONNET,HAIKU}_MODEL` 指到 catalog；context 1M 的加 `[1m]`，因为网关不替它确认扩展上下文。`apiKeyHelper` 读网关变量，不另设 `ANTHROPIC_AUTH_TOKEN`。
- 遥测开关全开：`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 外加冗余的单项开关（政策见 AGENTS.md 的 Telemetry）。`ENABLE_TOOL_SEARCH=false`：网关会丢 Anthropic server tool（`web_search` 实测，tool search 未实测）。这些放 settings `env` 而非 session 变量，从 Paseo 起的会话也生效。

### OMP（`omp.nix`）与 Pi（`pi.nix`）

- OMP 要显式设 `tools.approvalMode = "yolo"`，否则 ACP 仍可能询问。Pi 的内置工具直接执行；`defaultProjectTrust = "always"` 让新项目的扩展和 MCP 默认加载，已有的项目授权决定优先。
- 都用原生 provider ID 接网关，路由只覆盖 base URL 和凭据，provider 整体来自 `gatewayProviders.mkProviders`。OMP 的 Moonshot ID 是 `moonshot`，Pi 与 models.dev 用 `moonshotai`。
- OMP 生成 `~/.omp/agent/{models,config}.yml` 并合并 bundle 的 extension 与文件。`config.yml` 只读，所以关掉会写 `setupVersion` 的向导。
- Pi 的 `enabledModels` 取自 catalog，apiKey 写成网关变量的 `$NAME` 插值，`enableInstallTelemetry = false`（不管更新检查），`PI_SKIP_VERSION_CHECK=1` 只放在 HM session 变量里。Pi 对不可用的默认档位会静默回退，`checks.pi-default` 在新会话里核对实际默认值。

### Paseo（`paseo.nix`）

- NixOS 使用 `inputs.paseo.nixosModules.paseo`，系统服务以工作站用户运行，直接读取 SOPS 模板。上游 `services.paseo.settings` 会在重启时覆盖可写配置，因此只用 HM 合并 `~/.paseo/config.json`。
- 工作站 daemon 在 provider snapshot 中为 Codex、Claude、OMP 指定新会话默认模式，供客户端、CLI、MCP 和定时任务共用。客户端保存的模式、显式选择和受限父会话沿用上游行为。Pi 没有权限模式。升级 Paseo 时核对 `_paseo-default-modes.patch`。
- macOS 用 HM LaunchAgent 运行 llm-agents 的 `paseo-server`，cask 提供 GUI 和 CLI。两个桌面端均关闭 `manageBuiltInDaemon`，本机直连。devbox 支持 SSH 隧道和 relay：`services.paseo.relay.enable = true` 解除上游的 `--no-relay` 启动限制，实际开关由 Paseo 持久化。

## Bundle 与共享 skill

- **ponytail**（`inputs.ponytail`，`flake = false`）：OMP 把上游仓库根列进 `extensions`，loader 认 `package.json` 的 `pi.extensions`，`before_agent_start` 每轮注入 ruleset 并注册 `/ponytail` 档位与 `/ponytail-*` 命令。Codex 经 HM marketplace/cache 加载上游正式 plugin，Claude Code 直接挂上游 plugin。skill 由各家 plugin 自带，不铺共享副本。
- **caveman**（`inputs.caveman`）：上游没有 Pi adapter。bundle 给 OMP 提供 always-apply rule 与 `/caveman` command，给 Codex 生成封装上游 `.codex/hooks.json` 的最小 lifecycle plugin，给 Claude Code 挂上游 `.claude-plugin`。上游命令从 git 根目录找 `codex-sessionstart.js`，只在 caveman 自己的仓库里成立；bundle 改指 store 中的脚本，上游改写法时求值报错。`cavecrew`（依赖 Claude subagent）与 `caveman-stats`（依赖 Claude session hook）不铺进共享目录，Claude Code 经 plugin 自带；`caveman-shrink` 保持 opt-in。
- `skills.nix` 把 bundle 与 skill-only 输入逐项 link 到 `~/.agents/skills`，父目录保持可写，CLI 仍可装其他 skill。

## 遥测

政策见 AGENTS.md 的 Telemetry，证据见 `docs/research/agent-telemetry-2026-11-23.md`。Claude Code 的 env-vars/data-usage 文档出现新的单项开关时补上。若装 Grok CLI，在 `~/.grok/config.toml` 钉 `[telemetry] trace_upload = false`。
