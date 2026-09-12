# Pi Coding Agent 调查

> 调查日期：2026-08-11。本文所称 **Pi** 是 Mario Zechner 发起的 coding agent，历史入口为 [`badlogic/pi-mono`](https://github.com/badlogic/pi-mono)，调查时 GitHub 已将其解析到 [`earendil-works/pi`](https://github.com/earendil-works/pi)。上游 `main` 固定在 [`2a95ef70db83a19cf5500f31dc4ff8247e04043e`](https://github.com/earendil-works/pi/commit/2a95ef70db83a19cf5500f31dc4ff8247e04043e)，`@earendil-works/pi-coding-agent` 版本为 `0.84.1`。下文只按该完整 SHA 判断，避免 `main` 漂移。

## 结论

Pi 值得并行试用，但不应立刻替换当前 OMP：

1. **Pi 是刻意保持最小的终端 agent harness。** 默认只给模型 `read`、`write`、`edit`、`bash` 四个工具，不内置 subagents 或 plan mode；需要的工作流通过 TypeScript extensions、skills、prompt templates、themes 和 Pi packages 组合。见上游 [`coding-agent/README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/README.md)。
2. **它不是 OMP 的改名或精简发行版。** OMP 官方明确自称 Pi fork，但已形成独立的包名、版本、配置目录、运行时和内置工具面。两者有共同血缘，不代表当前 extension、package、配置或 session 可以无条件互换。见 OMP [`README.md`](https://github.com/can1357/oh-my-pi) 与 [`package.json`](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/package.json)。
3. **Pi 的强项是可塑性和嵌入能力。** 同一核心支持交互 TUI、print/JSON、RPC 和 SDK；extension 能拦截生命周期、注册工具/命令/快捷键/provider、修改 system prompt 与 compaction，并提供自定义 TUI。
4. **安全边界不是默认能力。** Pi 本身没有文件、进程、网络或凭据权限系统；进程、extensions 和 packages 默认拥有启动用户的完整权限。Project trust 只决定是否加载项目资源，不是沙箱。需要隔离时必须使用容器、OpenShell 或 Gondolin 类 tool-routing extension。
5. **本仓已经完成纯净接入。** 当前 `llm-agents` input 提供 `pi` `0.84.1`，[`adapters/pi.nix`](../../home/dev/agents/adapters/pi.nix) 安装它并从共享 catalog 生成独立配置。Pi 原生扫描 `~/.agents/skills`，所以继续复用 [`adapters/skills.nix`](../../home/dev/agents/adapters/skills.nix) 铺设的共享 skills。
6. **Pi 与 OMP 并存。** Pi 使用独立的 `~/.pi/agent/{settings,models}.json`，OMP 继续使用 `~/.omp/agent`；Pi adapter 不加载 behavior bundle、plugin、extension、prompt、theme 或 Pi package。

## 1. Pi 是什么

上游 monorepo 将能力拆成几层：

| 包 | 责任 |
|---|---|
| `@earendil-works/pi-ai` | 多 provider 统一 LLM API。 |
| `@earendil-works/pi-agent-core` | agent loop、tool calling 与状态管理。 |
| `@earendil-works/pi-coding-agent` | `pi` CLI、TUI、session、内置工具、资源加载与 SDK。 |
| `@earendil-works/pi-tui` | 终端 UI 与差分渲染。 |
| `@earendil-works/pi-telemetry` | vendor-neutral telemetry contracts 与适配层。 |

证据见固定版本的根 [`README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/README.md) 与 coding-agent [`package.json`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/package.json)。项目采用 MIT 许可证，见 [`LICENSE`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/LICENSE)。npm 安装要求 Node `>=22.19.0`；本仓若使用 Nix derivation，其 runtime 由 package closure 处理，不需要另行声明全局 Node。

### 1.1 四种运行方式

| 模式 | 用途 |
|---|---|
| Interactive | 完整终端 TUI，支持模型切换、消息队列、session tree、compaction 和 extension UI。 |
| Print / JSON | 单次或非交互调用，适合脚本与 CI。 |
| RPC | `pi --mode rpc`，通过 stdin/stdout 交换严格 LF 分隔的 JSONL command、response 与 event。 |
| SDK | Node/TypeScript 直接使用 `AgentSession` 等 API，避免再包一层子进程协议。 |

RPC 支持 prompt、steer、follow-up、abort、session/model/thinking 状态控制等操作；协议细节见 [`rpc.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/rpc.md)。

### 1.2 默认产品取舍

Pi 的默认面很小：

- 四个模型工具：`read`、`write`、`edit`、`bash`。
- session 自动保存、树形分支、fork/clone、HTML/JSONL 导入导出。
- 手动和自动 compaction；压缩有损，但完整历史仍留在 JSONL session。
- steering 与 follow-up 消息队列。
- provider/model 选择、thinking level、图片输入和 terminal image rendering。
- 不内置 subagents、plan mode、LSP、debugger、web search 或 browser；这些应由 extension/package 提供。

这不是缺漏列表，而是上游公开的产品哲学：核心保持可理解，用户按工作流扩展。是否适合本仓，关键不在功能总数，而在「四工具 + 自选 extensions」能否稳定完成日常任务。

## 2. 配置、模型与状态

### 2.1 文件布局

| 路径 | 内容 |
|---|---|
| `~/.pi/agent/settings.json` | 全局设置。 |
| `.pi/settings.json` | 项目设置，覆盖全局设置。 |
| `~/.pi/agent/models.json` | 自定义 provider/model catalog。 |
| `~/.pi/agent/trust.json` | 项目信任决定。 |
| `~/.pi/agent/sessions/` | 默认 session JSONL，按工作目录组织。 |
| `~/.pi/agent/extensions/` | 全局 extensions。 |
| `~/.pi/agent/skills/`、`~/.agents/skills/` | 全局 skills。 |
| `.pi/{extensions,skills,prompts,themes}/` | 受 project trust 控制的项目资源。 |

设置、优先级和 project trust 见 [`settings.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/settings.md)；session tree 与 compaction 见 [`coding-agent/README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/README.md)。

交互模式首次遇到包含项目设置或资源的未决目录时会询问信任。非交互模式无法显示该提示；若没有已有决定，则按全局 `defaultProjectTrust` 处理，CLI 也可用 `--approve` / `--no-approve` 覆盖单次调用。

### 2.2 Provider 与 model

Pi 内置多家 provider 的 tool-capable model catalog，支持 API key、`/login` subscription auth，以及 `~/.pi/agent/models.json` 自定义模型。固定版本原生支持这些 API 类型：

- `openai-completions`
- `openai-responses`
- `anthropic-messages`
- `google-generative-ai`

自定义 provider 可声明 `baseUrl`、`api`、`apiKey`、headers、models 与兼容参数；`apiKey`/headers 支持环境变量插值或命令取值。特殊 API 或 OAuth 也可由 extension 调用 `registerProvider()` 注册。完整 schema 见 [`models.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/models.md)。

**本仓推断：** [`home/ai-catalog.nix`](../../home/ai-catalog.nix) 已是 Codex/OMP 的 provider、endpoint 与 model 真源，新增 Pi adapter 时应从它生成 `models.json`，而不是复制一份模型表。Pi 与 OMP 的 JSON/YAML schema 不同，仍需要一层很薄的投影；不能直接复用 `~/.omp/agent/models.yml`。

### 2.3 Session

Pi session 是带 `id` / `parentId` 的 JSONL tree：

- `/tree` 在同一个 session 文件内切换历史分支。
- `/fork` 从历史 user message 创建新 session 文件。
- `/clone` 复制当前 active branch。
- `/compact` 或自动 compaction 总结旧内容，原始历史仍保留。
- `--no-session` 可做不落盘的临时试验。

Pi 与 OMP 虽都继承 Pi 的 session 概念，但当前实现和版本已独立演进。并存期不要共用 session 目录，也不要假定任一方能稳定恢复另一方新增的 entry/message 类型。

## 3. 扩展模型

### 3.1 Skills

Pi 实现 [Agent Skills specification](https://agentskills.io/specification)，启动时只把 skill name/description 放入 system prompt，需要时再读取完整 `SKILL.md`，也可显式运行 `/skill:<name>`。见 [`skills.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/skills.md)。

对本仓最有价值的是 Pi 原生扫描 `~/.agents/skills/`。当前 [`adapters/skills.nix`](../../home/dev/agents/adapters/skills.nix) 已逐项把 behavior bundle、agent-browser 和 mattpocock skills 链接到该目录，并保持父目录可写。因此：

- 初次接入 Pi 不需要新增 skill adapter。
- Pi 与 Codex 可共享同一批 Agent Skills。
- skill 是否真正可运行仍取决于其脚本、工具名和宿主能力；「被发现」不等于「跨 harness 完全兼容」。

### 3.2 Extensions

Pi extension 是由宿主直接加载的 TypeScript module，可：

- 注册模型可调用工具、slash command、shortcut、flag 和 provider。
- 监听 session、agent、message、model、tool 等 lifecycle event。
- 在 `before_agent_start` 注入 context 或修改 system prompt。
- 拦截、修改或阻止 tool call。
- 自定义 compaction、tool rendering、editor、widget、footer 与 overlay。
- 用 `appendEntry()` 把 extension state 写入 session。

完整 API 和事件顺序见 [`extensions.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/extensions.md)。TypeScript 由宿主通过 `jiti` 加载，无需预编译；extension 与 Pi 同进程运行，拥有 Pi 进程的完整权限。

### 3.3 Pi packages

Pi package 用 `package.json#pi` 或约定目录聚合：

```json
{
  "pi": {
    "extensions": ["./extensions"],
    "skills": ["./skills"],
    "prompts": ["./prompts"],
    "themes": ["./themes"]
  }
}
```

来源可以是 npm、git 或本地路径；用户级内容落在 `~/.pi/agent/{npm,git}`，项目级落在 `.pi/{npm,git}`。固定 npm version 或 git ref 不会被常规 package update 自动漂移。详情见 [`packages.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/packages.md)。

Pi package 不是权限边界：extension 可执行任意代码，skill 也可指示模型执行程序。声明式 Nix 环境应优先引用审查过的固定源码，避免让 `pi install` 成为第二套长期 mutable package manager。

## 4. Pi 与 OMP

OMP 官方 [`README.md`](https://github.com/can1357/oh-my-pi) 明确写明它是 Pi fork。本仓当前实际使用 OMP，并由 [`adapters/omp.nix`](../../home/dev/agents/adapters/omp.nix) 生成 `~/.omp/agent/{models,config}.yml`、加载 behavior bundle extensions/files。

| 维度 | Pi 0.84.1 | OMP 17.2.12（本仓当前） |
|---|---|---|
| 命令 | `pi` | `omp` |
| 上游包 | `@earendil-works/pi-coding-agent` | `@oh-my-pi/pi-coding-agent` |
| npm runtime | Node `>=22.19.0` | Bun `>=1.3.14` |
| 用户配置 | `~/.pi/agent/*.json` | 本仓生成 `~/.omp/agent/*.yml` |
| 默认工具面 | `read` / `write` / `edit` / `bash` | OMP 自带更大的工具与 harness surface |
| Subagents / plan | 核心不内置，交给 extension/package | OMP 内置相关能力 |
| 定位 | minimal、self-extensible harness | batteries-included Pi fork |

本仓于调查日运行 Nix eval 得到：

```nix
inputs.llm-agents.packages.x86_64-linux.pi.version  # "0.84.1"
inputs.llm-agents.packages.x86_64-linux.omp.version # "17.2.12"
```

**兼容性边界：** 两者仍共享不少 Pi 概念和历史 API，但只能按具体版本、manifest、import package name 与 event API 逐个验证 extension。尤其不要因为 Ponytail 的 `package.json#pi` 能被某一方识别，就推断其当前 TypeScript/JavaScript extension 在另一方也必然兼容。

## 5. 安全与运维边界

上游根 [`README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/README.md) 明确说明 Pi 没有内置 filesystem、process、network 或 credential permission system。默认运行模型工具、`!` 命令和 extensions 的位置就是启动 Pi 的主机与用户环境。

需要区分三件事：

1. **Project trust：** 防止未确认项目自动加载 `.pi` 设置、packages、extensions 和 project skills。
2. **Extension 自己的确认 UI：** 可以实现危险命令确认、路径保护等策略，但仍是同权限进程内的逻辑。
3. **真正隔离：** 把整个 Pi 放进 Docker/OpenShell，或用 Gondolin extension 把内置工具路由进 micro-VM。见 [`containerization.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/containerization.md)。

固定版本的 `enableInstallTelemetry` 默认 `true`，`enableAnalytics` 默认 `false`；关闭 install telemetry 不等于关闭 update check。Nix 管理的安装可以声明 `enableInstallTelemetry = false`，并用 `PI_SKIP_VERSION_CHECK=1` 禁止启动时自更新检查；需要完全关闭启动网络操作时才使用 `--offline` / `PI_OFFLINE=1`。见 [`settings.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/settings.md)。

## 6. 本仓当前接入

[`adapters/pi.nix`](../../home/dev/agents/adapters/pi.nix) 实现最小、纯净的并存方案：

1. 直接安装 `inputs.llm-agents.packages.${system}.pi`；无需新增 input 或自建 package。
2. 从 [`home/ai-catalog.nix`](../../home/ai-catalog.nix) 生成 `~/.pi/agent/models.json`，只投影 Pi 支持的模型字段。四种 wire API 使用独立的 `furtherverse-*` provider 名，避免覆盖 Pi 内置 provider catalog。
3. 生成最小 `settings.json`：默认 `gpt-5.6-sol`、`high` thinking，并关闭 install telemetry。
4. 设置 `PI_SKIP_VERSION_CHECK=1`；Pi 版本只随 Nix input 更新。
5. 继续使用现有 `~/.agents/skills`，不复制 skill tree。
6. 保持 Pi 的 `~/.pi/agent` 与 OMP 的 `~/.omp/agent` 分离；session、trust 和 auth 等运行态仍由 Pi 写入自己的目录。
7. 不给 Pi 加载 Ponytail/Caveman behavior bundle，也不声明 plugin、extension、prompt、theme 或 Pi package。

该实现只新增一个薄 adapter，不改 OMP，不复制 catalog，也不引入 Pi 自己的长期 mutable package 管理面。

## 一方证据索引

- Pi 固定源码：[`README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/README.md)、[`coding-agent/README.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/README.md)、[`package.json`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/package.json)、[`LICENSE`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/LICENSE)。
- Pi 配置与模型：[`settings.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/settings.md)、[`models.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/models.md)。
- Pi 扩展系统：[`skills.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/skills.md)、[`extensions.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/extensions.md)、[`packages.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/packages.md)。
- Pi 集成与安全：[`rpc.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/rpc.md)、[`containerization.md`](https://github.com/earendil-works/pi/blob/2a95ef70db83a19cf5500f31dc4ff8247e04043e/packages/coding-agent/docs/containerization.md)。
- OMP 官方：[`README.md`](https://github.com/can1357/oh-my-pi)、[`coding-agent/package.json`](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/package.json)。
- 本仓现状：[`adapters/pi.nix`](../../home/dev/agents/adapters/pi.nix)、[`adapters/omp.nix`](../../home/dev/agents/adapters/omp.nix)、[`adapters/skills.nix`](../../home/dev/agents/adapters/skills.nix)、[`home/ai-catalog.nix`](../../home/ai-catalog.nix)、[`flake.lock`](../../flake.lock)。
