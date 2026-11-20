# Omarchy 的 agent 友好配置调研与本仓借鉴（2026-11-21）

## 结论

- **Omarchy 已把自己定位成 “agentic OS”**：README 写 “beautiful, fun & agentic Linux distribution”，4.5 发布文写 “Omarchy is the agentic OS”。落到配置上主要有四块：系统 skill、跨 harness 的统一 `~/.agents/AGENTS.md`、agent 启动器（默认免审批）、`omarchy` CLI 的机器可读命令清单。没有 MCP server。
- **安全网比想象中薄**：Snapper 只快照 `/`（btrfs `@`），只在 `omarchy update` 前拍，留 5 个，timeline 关闭；`/home` 不快照。手册明说回滚“不能找回丢失的个人文件”。所以 agent 删错仓库文件时，Omarchy 不兜底。它防的是“系统被更新或 agent 改坏”，靠的是 root 快照、Limine 启动菜单与 `omarchy reinstall configs`。
- **sudo 与 Docker 比本仓严**：默认要密码；agent 长时间做系统活时，用户可以开一个有时限的免密 sudo（15 分钟到 1 天，或永久），bar 上亮红色图标。用户默认不在 `docker` 组。本仓 `AGENTS.md` 已把免密 sudo 与 `docker` 组定为接受的取舍，本文不建议改。
- **shell 结论与本仓一致**：Omarchy 的 bashrc 先 source `env-bootstrap`（PATH 与 `OMARCHY_PATH`），再用 `[[ $- != *i* ]] && return` 挡住 alias、函数和 zoxide 的 `cd`。这正是本仓 `.zshrc` 顶部守卫的做法。选 bash 的公开理由只有“很多地方绑定了 bash”，与 agent 无关。
- **本仓最值得做的三件事**：① 在 `modules/agents/skills.nix` 发一个本机系统 skill，再加一份全局 `~/.agents/AGENTS.md`，成本低、收益最大；② 在 awesome-pc 上保护 `$HOME`：现在先用 restic 每小时本地快照，下次重装再换 btrfs + snapper；③ Mac 依赖 APFS 本地快照或 Time Machine 前，先核实没有备份目的地时能否用。系统级回滚已有 NixOS / nix-darwin generations，不必模仿 Omarchy 的 root 快照。

## 来源约定

- `Q` 指 `omacom/omarchy` 的 `quattro` 分支 [`40556923`](https://github.com/omacom/omarchy/tree/40556923f740728bba176ca4035a25d9e203ff21)（2026-11-20）。`M` 指 `master` 分支 [`f4378f0d`](https://github.com/omacom/omarchy/tree/f4378f0de5b44d331ee943746a97872b718a6c18)（2026-08-14）。下文链接都钉在这两个 commit 上。
- 手册的权威来源是仓库里的 `manual/`（[README](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/README.md#L7-L9)），所以手册也引用 `Q` 中的文件。
- 发布说明见 GitHub Releases [v4.0.0](https://github.com/omacom/omarchy/releases/tag/v4.0.0)、[v4.5.0](https://github.com/omacom/omarchy/releases/tag/v4.5.0) 和 [omarchy.org 4.5 发布文](https://omarchy.org/news/2026/11/omarchy-4-5/)。

## 1. 分支与版本

| 项 | 事实 | 来源 |
|---|---|---|
| 默认分支 | `quattro`（`origin/HEAD -> origin/quattro`） | clone 时 `git branch -a` |
| `quattro` | 4.x 线，把 Omarchy 装成 pacman 包（OPR 仓库），文件在 `/usr/share/omarchy` | [manual/30-updates.md L5](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/30-updates.md#L5)、[env-bootstrap L10-L16](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/env-bootstrap#L10-L16) |
| `master` | 3.x 旧线：`version` 文件是 `3.8.5`，最后一个 commit 是 “Omarchy 3.8.5 (#6875)”（2026-08-14）；git clone 安装到 `~/.local/share/omarchy`。比 `quattro` 落后 3763 个 commit，只领先 34 个 | [M/version](https://github.com/omacom/omarchy/blob/f4378f0de5b44d331ee943746a97872b718a6c18/version)、[M/default/bashrc L6](https://github.com/omacom/omarchy/blob/f4378f0de5b44d331ee943746a97872b718a6c18/default/bashrc#L6)、`git rev-list --count` |
| 旧机迁移 | `omarchy-upgrade-to-quattro` 把任何 pre-quattro 安装升级到 package-backed 布局，可作为 3.8.x 命令运行，也可 `curl \| bash` | [Q/bin/omarchy-upgrade-to-quattro L3, L14-L16](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-upgrade-to-quattro#L3-L16) |
| 新装追踪 | 新装默认走 stable 渠道，追官方 release；stable 用的 Arch 镜像比上游晚一个月。另有 rc、edge（最新开发构建）、dev（链接 `~/omarchy` 的 git checkout）三个渠道 | [manual/30-updates.md L11-L21](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/30-updates.md#L11-L21) |
| 最新 release | **v4.5.0**（“Quattro RS”），GitHub 标为 Latest，发布于 2026-11-05T05:36Z；tag commit `ac2690cd`（2026-11-04）。它在发布分支 `v4-5-0` 上，**不在** `quattro` 上 | [v4.5.0](https://github.com/omacom/omarchy/releases/tag/v4.5.0)、`gh release list`、`git merge-base --is-ancestor` |
| 之前的版本 | v4.0.0（2026-08-14）是 Quattro 首发；v4.0.6 发布于 2026-10-19 | [v4.0.0](https://github.com/omacom/omarchy/releases/tag/v4.0.0)、`gh release list` |

`quattro` HEAD 的 `version` 文件仍是 `4.0.0.alpha`（[Q/version](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/version)），所以它不能用来判断版本。远端还有 `v4-5-1` 分支（2026-11-17），但没有对应 tag。[INFERENCE] 4.5.1 正在准备。

`pi` 与 `omarchy-skill` 的去向：在 `master` 上是 `default/pi/agent/extensions/omarchy-system-theme.ts` 与 `default/omarchy-skill/SKILL.md`。在 `quattro` 上，skill 由 [`6ee243cc`](https://github.com/omacom/omarchy/commit/6ee243cc3740563bf8a19dd249db2a9304eedd43)（#6602，2026-08-07）拆成 `default/agents/skills/omarchy/` 下的主题指南。Pi 主题扩展由 [`da53c0ff`](https://github.com/omacom/omarchy/commit/da53c0ff60e9d41a00a84c6afd35c3d132225b4a)（2026-05-20）改成生成 `~/.pi/agent/themes` 的 [`bin/omarchy-theme-set-pi`](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-theme-set-pi#L1-L12)。

## 2. Omarchy 自带的 agent 集成

### 2.1 Skills

| 分支 | 内容 | 安装方式 |
|---|---|---|
| `master` | 一个 392 行的 `omarchy` skill，外加 Pi 主题扩展 | [install/config/omarchy-ai-skill.sh L1-L8](https://github.com/omacom/omarchy/blob/f4378f0de5b44d331ee943746a97872b718a6c18/install/config/omarchy-ai-skill.sh#L1-L8)：`ln -sfn` 到 `~/.agents/skills`、`~/.claude/skills`、`~/.codex/skills`、`~/.pi/agent/skills`，扩展用 `cp` |
| `quattro` | `default/agents/skills/` 下有 `omarchy`（主文件加 `hyprland/shell/theming/apps/system/hooks/capture` 七个主题指南）、`diagnose-crash`、`omarchy-contribute`、`omarchy-make-{app,game,plugin,theme}` | [bin/omarchy-agent-skills-link L7-L46](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-agent-skills-link#L7-L46)：逐个 skill 软链到 6 个 harness 目录与每个 Hermes profile；用户自己的同名目录或链接优先；指向旧树的链接会被移走或删除 |

- **何时链接**：每个用户 provision 时运行（[bin/omarchy-provision-user L84-L90](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-provision-user#L84-L90)）；新增或改名 skill 时用 migration 重链（[migrations/1795093910.sh](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/migrations/1795093910.sh#L1-L6)）。之所以用软链而不复制，是为了 `omarchy dev link` 后链接自动指向开发 checkout（[docs/file-layout.md L272](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/docs/file-layout.md#L272)）。skill 内容随 `omarchy` 包更新。
- **`omarchy` skill 的关键规则**（[SKILL.md](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md)）：
  - description 写 “REQUIRED for end-user customization”，并列出 `~/.config/...` 路径作为触发词（[L1-L16](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L1-L16)）。
  - **永远不改 `/usr/share/omarchy/`**，但鼓励读它；只改 `~/.config/`（[L40-L71](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L40-L71)）。
  - 提权：有终端时用 `sudo`；agent 或后台进程没有终端时才用 `pkexec`（[L73-L83](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L73-L83)）。
  - 命令发现：`omarchy commands`、`omarchy <group> --help`、`omarchy commands --json`，并鼓励读命令源码（[L100-L120](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L100-L120)）。
  - 运行 `omarchy refresh` 或 `reinstall` 前必须征得用户确认（[L206-L258](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L206-L258)）。
  - `omarchy-debug` 必须带 `--no-sudo --print`，避免 sudo 提示挂住 agent（[L226-L234](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/SKILL.md#L226-L234)）。
- **手册的态度**：这个 skill 是 experimental；建议先用 plan mode，准备好回滚，必要时运行 `omarchy reinstall configs`（[manual/17-ai.md L129-L133](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L129-L133)）。

### 2.2 全局指令

- 个人规则写在 `~/.agents/AGENTS.md`。`omarchy agent instructions` 把它软链到各 harness 自己的全局文件（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.pi/agent/AGENTS.md` 等）；已有的文件改名为 `.bak`。按 Omarchy 的说法，omp、Kimi、DSH 直接读 `~/.agents/AGENTS.md`（[manual/17-ai.md L55-L57](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L55-L57)，[bin/omarchy-agent-instructions L7-L54](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-agent-instructions#L7-L54)）。
- 仓库根目录的 `AGENTS.md` 与 `CLAUDE.md`（内容只有 `@AGENTS.md`）是给贡献者 agent 的，指向 `agents/skills/*.md` 任务指南（[Q/AGENTS.md L1-L30](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/AGENTS.md#L1-L30)），不随系统安装。

### 2.3 目标 agent、安装与启动

- **手册列出 21 个 CLI agent**，包括 `claude`、`codex`、`opencode`、`omp`、`pi`、`dsh`、`grok` 等；Omarchy 不替用户选默认 agent（[manual/17-ai.md L1-L29](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L1-L29)）。首次启动时只发一次通知，邀请用户选择（[install/user/first-run/setup-agent.hook L5-L10](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/install/user/first-run/setup-agent.hook#L5-L10)）。
- **安装与更新**：用 mise lazy 安装，首次运行时才装；agent 带 `auto_update = "4h"`（[etc/mise/conf.d/omarchy-tools.toml L10-L44](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/etc/mise/conf.d/omarchy-tools.toml#L10-L44)）。`upgrade.auto_prune = false`，避免删掉运行中 agent 正在用的版本；mise 的 `postinstall` 钩子装 herdr 状态集成（[etc/mise/conf.d/omarchy.toml L1-L13](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/etc/mise/conf.d/omarchy.toml#L1-L13)，[bin/omarchy-agent-integrate-herdr L6-L37](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-agent-integrate-herdr#L6-L37)）。agent 自己的更新器不受支持（[manual/17-ai.md L33-L39](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L33-L39)）。
- **默认免审批**：快捷键、菜单和 `a` 启动的 agent 都以各自的 “don't stop to ask” 模式运行，例如 `omp --auto-approve`、`codex --approve-for-me`、`DSH_PERMISSION_MODE=danger-full-access`（[bin/omarchy-agent L140-L236](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-agent#L140-L236)，[manual/17-ai.md L51-L53](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L51-L53)）。从 `$HOME` 启动时会改到 `~/Work`，因为 agent 不会为 `$HOME` 记住信任（[bin/omarchy-agent L63-L65](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-agent#L63-L65)）。
- **MCP**：`quattro` 里只在账户迁移时提到保留各 agent 自己的 MCP 配置，Omarchy 不提供 MCP server（`rg -i '\bmcp\b'` 只命中 `bin/omarchy-agent-account-*`）。

## 3. 人用 shell 与 agent 用 shell

| 层 | 内容 | 来源 |
|---|---|---|
| `/etc/skel/.bashrc`（来自 `default/bashrc`） | 第 2 行 source `env-bootstrap`，注释写明 “needed even for non-interactive shells”；第 5 行 `[[ $- != *i* ]] && return`；之后才 source `default/bash/rc` | [Q/default/bashrc L1-L9](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bashrc#L1-L9)、[docs/file-layout.md L126-L127](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/docs/file-layout.md#L126-L127) |
| `env-bootstrap` | `OMARCHY_PATH` 与 PATH 的单一来源：把 mise command-wrappers 放到最前，让脚本也跟着账户切换；在末尾追加 `~/.local/share/mise/shims` 与 `~/.local/bin` | [env-bootstrap L1-L62](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/env-bootstrap#L1-L62) |
| 其他入口 | `/etc/profile.d/omarchy.sh`（login shell）、uwsm `env.d/10-omarchy`（图形会话）；`ssh host cmd` 什么 shell 初始化都不跑，所以在 PAM 的 `pam_env.conf` 里写 PATH | [etc/profile.d/omarchy.sh](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/etc/profile.d/omarchy.sh#L1)、[install/config/ssh-command-path.sh L1-L11](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/install/config/ssh-command-path.sh#L1-L11) |
| `rc` 链（仅交互） | `envs`、`shell`、`aliases`、`functions`、`init`；`init` 里有 `mise activate`、starship（仅交互且不是 dumb 终端）、`zoxide init`，`try` 懒加载 | [rc L1-L7](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/rc#L1-L7)、[init L1-L29](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/init#L1-L29) |
| `envs` | 再 source 一次 `env-bootstrap`，覆盖 SSH 与非 login 的 bash；`LANG` 为空时补上 locale，修复 herdr 远程桥里的 `\u` 转义问题 | [envs L15-L29](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/envs#L15-L29) |
| zoxide 的 `cd` | `alias cd="zd"`：目录存在就 `builtin cd`，否则调用 `z` 跳到历史目录。它在守卫之后，只在交互 shell 生效 | [aliases L18-L35](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/bash/aliases#L18-L35) |

- **演变**：在 `master` 上，守卫是 bashrc 第一行，之前什么都不 source（[M/default/bashrc L1-L6](https://github.com/omacom/omarchy/blob/f4378f0de5b44d331ee943746a97872b718a6c18/default/bashrc#L1-L6)）。[`b9254310`](https://github.com/omacom/omarchy/commit/b925431025e02c9c438b27bd8157dc36c847a6a5)（#6632，2026-08-08）把 `env-bootstrap` 移到守卫之前。commit 说明：`ssh host cmd` 找不到 mise 管理的 agent CLI，而有些 bash 变体会非交互地读 bashrc。[`f9646299`](https://github.com/omacom/omarchy/commit/f9646299bf80f94c2694eb2592fb949e820a7604)（#14233）又把 command-wrappers 提到 PATH 最前，让 CLI 子进程也跟随账户切换。
- **为什么选 bash 而不是 zsh 或 fish**：DHH 在 [PR #1907](https://github.com/omacom/omarchy/pull/1907#issuecomment-3333725667) 写道 “we have a bunch of ties on bash that would break with this… not interested in maintaining any big changes to accommodate radically different shells”。之后又说 “the only path forward I'm currently looking to consider is switching to zsh”（[comment](https://github.com/omacom/omarchy/pull/1907#issuecomment-3373876387)，2025-10-06）。没有找到任何以 agent 为理由的说法。

## 4. 防 agent 破坏的安全网

### 4.1 Snapper / btrfs / Limine

| 项 | 事实 | 来源 |
|---|---|---|
| 子卷 | 根是 `@`（factory reset 检查 `subvol=/@`）；另有 `@home`、`@log`、`@factory`（Quattro 安装器装完立即拍的基线）和 `/.snapshots` 子卷 | [omarchy-system-factory-reset L11-L14](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-system-factory-reset#L11-L14)、[omarchy-system-factory-reset-finish L9-L16](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-system-factory-reset-finish#L9-L16) |
| Snapper 配置 | 只有 `root` 一个配置，`SUBVOLUME="/"`；`NUMBER_LIMIT=5`、`NUMBER_LIMIT_IMPORTANT=5`、`NUMBER_MIN_AGE=0`；`TIMELINE_CREATE="no"` | [default/snapper/root L1-L10](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/snapper/root#L1-L10) |
| 定时器 | 安装时关闭 `snapper-timeline.timer`，打开 `snapper-cleanup.timer` 与 `limine-snapper-sync.service` | [install/config/snapper.sh L17-L24](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/install/config/snapper.sh#L17-L24) |
| 何时拍 | 只在 `omarchy update` 里拍：先清 pacman 缓存，再执行 `omarchy-snapshot create`（`snapper create -c number` 后立刻 `cleanup number`）。快照失败也继续更新，但会明确提示 | [bin/omarchy-update L91-L99](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-update#L91-L99)、[bin/omarchy-snapshot L20-L45](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/bin/omarchy-snapshot#L20-L45) |
| pre/post 钩子 | 没有逐个 pacman 事务的 pre/post 快照：包列表里只有 `snapper`、`limine-snapper-sync`、`btrfs-progs`，没有 `snap-pac`。手动 `pacman -Syu` 会被拦截，要求改用 `omarchy update` | [install/omarchy-other.packages L9, L22, L42](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/install/omarchy-other.packages#L9-L42)、[manual/30-updates.md L33-L35](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/30-updates.md#L33-L35) |
| 进入快照 | 在 Limine 菜单选快照启动，再点通知或执行 `omarchy-snapshot restore`（`limine-snapper-restore`）。只有用 Limine 引导的安装支持 | [manual/47-system-snapshots.md L3-L21](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/47-system-snapshots.md#L3-L21) |
| 覆盖范围 | **只恢复根文件系统，不恢复 `/home`**，“not for recovering lost personal files”；`~/.config` 与 migration 记录都保持原样 | [manual/47-system-snapshots.md L15-L19](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/47-system-snapshots.md#L15-L19) |
| 4.5 的变化 | Limine 菜单从约 6 秒缩短到 1 秒，开机时按住任意键才停在菜单 | [4.5 发布文](https://omarchy.org/news/2026/11/omarchy-4-5/) “Omarchy used to show the boot menu for about six seconds…” |

### 4.2 trash 与 rm

没有 `rm` 别名，没有 trash-cli，也没有 safe-rm。在 `default/`、`bin/`、`install/`、手册与 `docs/` 里搜 `trash|rm -i|alias rm|safe-rm|gio trash`，只命中 Omaview 的 Delete 键和 `diagnose-crash` skill 里的一句话。

### 4.3 sudo 与 Docker

- 默认要密码。_Setup > Security > Passwordless Sudo_ 可以开 15 分钟、1 小时、1 天或永久的免密授权，bar 上会出现红色警示图标。手册明确写了使用场景：“most often when an AI agent is doing a long stretch of system work”。手册也写明风险：“anything running as your user can do anything as root”（[manual/48-security.md L21-L29](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/48-security.md#L21-L29)）。
- 实现方式：sudoers 规则加 `NOTAFTER` 截止时间，由 sudo 自己强制执行，跨 suspend 也有效；永久授权写在 `/etc/sudoers.d/99-omarchy-permanent-nopasswd-<uid>`（[docs/passwordless-sudo.md L9, L17](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/docs/passwordless-sudo.md#L9-L17)）。
- 用户默认不在 `docker` 组，理由是 “effectively passwordless root… a single rogue script or dependency running as you would otherwise be one command away from root”（[manual/18-development-tools.md L56](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/18-development-tools.md#L56)）。
- 最后的兜底：`omarchy reinstall` 或 `omarchy reinstall configs` 重置配置（[manual/30-updates.md L37-L43](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/30-updates.md#L37-L43)）。factory reset 依赖 `@factory` 快照（[manual/48-security.md L15-L19](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/48-security.md#L15-L19)）。

## 5. 与 agent 相关的默认 CLI

| 工具 | 方式 | 来源 |
|---|---|---|
| `ripgrep`、`fd`、`jq`、`git`、`lazygit`、`fzf`、`bat`、`eza`、`zoxide`、`tldr`、`tmux`、`herdr`、`gum`、`mise-bin`、`tobi-try` | pacman 基础包 | [install/omarchy-base.packages](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/install/omarchy-base.packages)（第 44、50、52、59、63、75、77、88、136、149、151、152、176 行） |
| `gh`、`uv`、`node`、`playwright`、`hunk`、`ghui` 以及全部 agent CLI | mise lazy 安装，首次运行时才装 | [omarchy-tools.toml L13-L44](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/etc/mise/conf.d/omarchy-tools.toml#L13-L44)、[manual/18-development-tools.md L21-L46](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/18-development-tools.md#L21-L46) |
| git 配置 | `pull.rebase`、`push.autoSetupRemote`、`diff.algorithm=histogram`、`diff.colorMoved`、`commit.verbose`、`rerere.enabled` 与 `autoupdate` | [config/git/config L1-L28](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/config/git/config#L1-L28) |
| `try` | 实验目录放在 `~/Work/tries`。`bin/` 不自动加进 PATH，项目工具要显式写 `./bin/x` | [manual/19-shell-tools.md L57-L61](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/19-shell-tools.md#L57-L61) |
| 布局函数 | `tdl`、`tdlm`、`tsl` 等 tmux 布局，把编辑器与 agent 并排放 | [manual/15-terminal.md L17-L39](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/15-terminal.md#L17-L39) |

明确为 agent 准备的只有：agent CLI 与 `gh` 的 lazy 安装；在 PATH 中排在最前的 command-wrappers；4.5 修复的 “agents not finding mise tools installed after they started”（[4.5 发布文](https://omarchy.org/news/2026/11/omarchy-4-5/)）；以及 `omarchy commands --json`。

## 6. 凭据与提醒

- **凭据**：Omarchy 管的只是 agent 的**订阅登录**。`omarchy agent account` 支持多个 Claude、Codex、Grok 账号切换，并可经 SSH 一次性把登录复制到其他机器（[manual/17-ai.md L65-L79](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L65-L79)）。本地模型的 key 放在 `~/.config/omarchy/agent-local/key`（[L119](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L119)）。API key 环境变量没有统一注入机制；1Password 只是可选安装（[manual/24-commercial-apps-services.md L5-L9](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/24-commercial-apps-services.md#L5-L9)）。
- **提醒**：
  - 活跃账户超过 95% 用量时发通知，点击后切到余量最多的账户；也可以设为自动切换（[manual/17-ai.md L77](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L77)）。
  - systemd-coredump 记录到进程崩溃时发 critical 通知，点击后交给默认 agent 与 `diagnose-crash` skill（[manual/17-ai.md L81-L87](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L81-L87)，[docs/notifications.md L208-L213](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/docs/notifications.md#L208-L213)）。
  - agent 的运行状态（忙、完成、需要输入）交给 herdr，通过 mise postinstall 安装 herdr integration（§2.3）。
  - Omarchy 本身没有 “agent 完成” 的桌面通知。远端有 `agent-awake` 分支，但 `quattro` 上没有对应命令（`bin/` 下只有更新时防休眠的 `omarchy-update-stay-awake`）。

## 7. 其他明确以 agent 友好为卖点的内容

- README 与 4.5 发布文自称 “agentic”、“The malleable OS for the age of agents”（[README L3](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/README.md#L3)，[4.5 发布文](https://omarchy.org/news/2026/11/omarchy-4-5/)）。
- 4.0 的默认 agent 选择器：`SUPER+SHIFT+CTRL+A` 或 `a` 启动，在 `~/Work` 打开 “so trust actually sticks”（[v4.0.0 release](https://github.com/omacom/omarchy/releases/tag/v4.0.0) “Pick your coding agent”）。4.5 加了 Quake 式 agent 下拉控制台和 agents 用量面板（[4.5 发布文](https://omarchy.org/news/2026/11/omarchy-4-5/)）。
- Agents 面板的 _Make something_ 把新主题、插件、app、游戏的 starter prompt 交给默认 agent，对应各自的 `omarchy-make-*` skill（[manual/17-ai.md L61](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L61)）。
- 本地模型：`omarchy agent local use best` 用 Podman 在本机跑模型，不联网（[manual/17-ai.md L101-L123](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/manual/17-ai.md#L101-L123)）。
- 系统 skill 的环境变量指南：整个桌面要用的变量放 `~/.config/uwsm/env.d/`；写错会回到登录界面，所以要求 agent 保持语法简单，并告诉用户如何撤销（[system.md L5-L9](https://github.com/omacom/omarchy/blob/40556923f740728bba176ca4035a25d9e203ff21/default/agents/skills/omarchy/system.md#L5-L9)）。

## 本仓适用性

本仓现状来自 `AGENTS.md`、`modules/shell/zsh.nix`、`modules/users.nix`、`modules/agents/{codex,omp,skills,default}.nix`、`modules/dev/{languages,git}.nix`、`modules/shell/tools.nix`、`modules/home.nix`、`modules/nixos/{base,daily,systemd-boot}.nix`、`modules/nix.nix` 与 `hosts/awesome-pc/disko.nix`（本仓 `87b5031`）。

| Omarchy 做法 | 本仓状态 | nix-darwin + NixOS 的具体落法 | 成本 / 风险 |
|---|---|---|---|
| 系统 skill：“只改用户层，不改包管理的目录；先查命令” | **缺失**。`skills.nix` 只链接第三方 skill；仓库级 `AGENTS.md` 只在本仓内生效 | 新建 `modules/agents/_skills/nix-config/SKILL.md`（`_` 前缀不被 auto-import）。在 `skills.nix` 的 `managedSkills` 里加 `// { nix-config = ./_skills/nix-config; }`，链接到 `~/.agents/skills`。内容：系统是声明式的；不要手改 `/nix/store`、HM 管理的只读链接或 `~/.omp/agent/config.yml`；装软件、改配置都改 `~/nix-config` 再 `just switch <host>`；不要 `brew install`、`nix profile install`、`npm -g`；临时工具用 `nix run nixpkgs#x` / `nix shell`；回滚命令；密钥在 `~/.cache/op-env/env`，用 `op-env-refresh` 刷新 | 低。注意 description 的触发面不能太宽，避免抢其他 skill |
| `~/.agents/AGENTS.md` 统一全局规则，再软链到各 harness | **缺失**（没有全局个人规则文件） | `home.file.".agents/AGENTS.md".text`，再加 `home.file.".codex/AGENTS.md".source` 指向同一文件。omp 无需链接：v19.0.1 会从用户主目录的 `.agent`/`.agents` 读 `AGENTS.md`（[discovery/agents.ts L275-L297](https://github.com/can1357/oh-my-pi/blob/f40f335845f0b136453d12fec8d6057011082766/packages/coding-agent/src/discovery/agents.ts#L275-L297)）。[INFERENCE] HM `programs.codex` 可能有专门写 AGENTS.md 的选项，落地前查一次。DSH 是否读取只有 Omarchy 的说法 | 低。内容要短，否则每轮都消耗 token |
| `env-bootstrap` 在交互守卫之前提供 PATH | **已有**。`.zshrc` 以 `[[ -o interactive ]] \|\| return` 开头（`zsh.nix` L113）；静态 PATH 放在 `home.sessionPath` | [INFERENCE] HM 把 session 变量写进 `.zshenv`，NixOS 与 nix-darwin 的 `/etc/zshenv` 也设置 PATH，所以 `zsh -lc` 与 `ssh host cmd` 都能拿到 PATH，不需要 `pam_env` | 无 |
| `ssh host cmd` 的 PATH 写进 `pam_env` | 不适用（理由同上） | — | — |
| 更新前拍 root 快照，在 Limine 菜单回滚 | **已有等价物**：NixOS generations 加 systemd-boot `configurationLimit = 10`、`just rollback`；nix-darwin 与 HM 的 generations；GC 保留 30 天 | 只需在系统 skill 里写清回滚命令 | 无 |
| Snapper 的 `/`、`NUMBER_LIMIT=5`、不开 timeline | 不适用（root 已由 generations 覆盖） | — | — |
| `/home` 快照（Omarchy **也没有**） | **缺失**。awesome-pc 根分区是 ext4，`/home` 也在上面；Mac 没有 Time Machine 目的地（本机 `tmutil destinationinfo` 输出 “No destinations configured”） | **NixOS 现在就能做**：`services.restic.backups.home`（本仓 `hosts/ovh-ks-5/backup.nix` 已有同类写法），`paths = [ "/home/<user>/Developer" "/home/<user>/nix-config" ]`，`timerConfig.OnCalendar = "hourly"`，`pruneOpts = [ "--keep-hourly 48" "--keep-daily 14" ]`，本地仓库放 `/var/lib/restic-home`。**下次重装**：在 `disko.nix` 把 root 改成 `type = "btrfs"`，加 `subvolumes."/home"` 等；再配 `services.snapper.configs.home = { SUBVOLUME = "/home"; TIMELINE_CREATE = true; TIMELINE_CLEANUP = true; TIMELINE_LIMIT_HOURLY = …; }`。本机 nixpkgs 副本的 `snapper.nix` 里有 `SUBVOLUME`、`TIMELINE_LIMIT_HOURLY`、`snapshotInterval`、`cleanupInterval` 等选项 | restic：低到中，占磁盘；同盘仓库只防误删，不防坏盘。btrfs：高，disko 重装要清盘，`/home` 要先迁出 |
| macOS 上的同类保护 | **缺失** | [INFERENCE] 用 nix-darwin 的 `launchd.daemons.<name>` 每小时跑 `tmutil localsnapshot`。man 页写的是 “local Time Machine snapshots of all APFS volumes included in the Time Machine backup”，没有目的地时是否生效未验证；本地快照会被系统自动 thin。更稳的做法：给 Time Machine 配一个外接盘或 NAS 目的地，或者与 NixOS 共用 restic | 低到中。先手动验证 `tmutil localsnapshot` 后再写进模块 |
| trash 与 `rm` 保护 | Omarchy 也没有 | 不建议加 `rm` 别名：agent shell 在守卫之前就退出了，别名不会生效，反而给人虚假的安全感 | — |
| 有时限的免密 sudo，带红色指示 | **有意不同**：daily 主机永久免密（`users.nix` L20、L43）；`AGENTS.md` 写明 “Do not ‘harden’ them” | 不改。如果策略变了：[INFERENCE] `security.sudo.extraRules` 的 options 枚举未必能表达 `NOTAFTER`，可能要改用 `security.sudo.extraConfig` 手写 | 改了会打断 `just switch` 与 agent 的系统操作 |
| 默认不进 `docker` 组 | **有意不同**（`users.nix` L13-L16 授予了 `docker` 组） | 不改，理由同上 | — |
| agent 默认免审批启动 | **已有**：Codex `approval_policy = "never"` + `danger-full-access`（`codex.nix` L39-L40），DSH 也是 full access | — | 与 Omarchy 一致，所以更需要 `$HOME` 快照 |
| agent CLI 用 mise lazy 安装并 4 小时自动更新；herdr postinstall 钩子 | 不适用：由 Nix 从 `llm-agents` 固定版本，每周 flake update；omp 与 Codex 原生通过 OSC 7501 向 herdr 报告状态 | — | — |
| 安装后新出现的工具，运行中的 agent 也能找到 | **已有**。[INFERENCE] `useUserPackages` 后 PATH 指向固定的 per-user profile 目录，switch 后原地更新 | — | — |
| 默认 CLI：`rg`、`fd`、`jq`、`gh`、`lazygit`、`fzf`、`bat`、`eza`、`zoxide`、`mise`、`herdr` | **已有**（`tools.nix`、`home.nix`、`git.nix`、`languages.nix`、`desktop/herdr.nix`） | 缺 `tldr` 与 `try`，对 agent 的价值都很低，不建议加 | — |
| git 默认配置 | **基本已有**（`pull.rebase`、`autoSetupRemote`、`histogram`、`rerere`） | 可选：`commit.verbose`、`rerere.autoupdate`。后者会让 agent rebase 时静默套用旧的冲突解法，**不建议** | — |
| `omarchy commands --json` 机器可读命令清单 | 部分已有：`just --list` | 在系统 skill 里写 `just --list`、`just --dump --dump-format json` | 无 |
| 崩溃时把 core 交给 agent 诊断（`diagnose-crash`） | 缺失 | 可选：NixOS 自带 systemd-coredump，可以写一个 skill 教 agent 用 `coredumpctl` | 低收益 |
| 用量与限额通知、多账户切换 | 不适用（走自建网关的 API key） | — | — |
| factory reset、Limine | 不适用 | — | — |

## 建议（按 agent 友好与安全排序）

1. **发系统 skill 和全局 `AGENTS.md`**。在 `modules/agents/_skills/nix-config/` 写 skill，在 `skills.nix` 加一行链接。再用 HM 生成 `~/.agents/AGENTS.md`，并链接到 `~/.codex/AGENTS.md`。这是 Omarchy 最核心的 agent 化手段，在本仓几乎零风险，还直接降低 agent 用 `brew`、`npm -g` 或手改只读链接造成配置漂移和失败的概率。
2. **awesome-pc 的 `$HOME` 数据保护，现在就做 restic**。`services.restic.backups.home`，每小时跑，仓库放本机，只备份 `~/Developer` 与 `~/nix-config`，再排除 `node_modules`、`.direnv`、`target`。原因：Omarchy 的 root 快照恰好不覆盖 agent 最常破坏的地方，而本仓 agent 是 full access 且不审批。
3. **下次重装 awesome-pc 时换 btrfs + snapper（只配 `/home`）**。改 `hosts/awesome-pc/disko.nix` 与 `services.snapper.configs.home`；timeline 每小时，保留 24 到 48 个。root 继续靠 generations，不要复制 Omarchy 的 root 配置。之后第 2 条可以降为异地备份。
4. **Mac：先验证再落地**。手动跑一次 `tmutil localsnapshot` 与 `tmutil listlocalsnapshots /`，看没有目的地时是否生效。生效就写 `launchd.daemons` 每小时一次；不生效就配 Time Machine 目的地，或者复用第 2 条的 restic。
5. **在 skill 里写清回滚手册**：`just rollback`、`darwin-rebuild --rollback`、`home-manager generations`、restic restore 命令。这对应 Omarchy 手册的 “be ready to rollback”。
6. **维持现有取舍**：免密 sudo、`docker` 组与 zoxide 守卫都不动；不加 `rm` 别名或 trash 包装。

## 未能核实

- `quattro` 与 `master` 之外，edge 和 dev 渠道的包具体从哪个分支构建，仓库里没有直接写明；`dev` 分支已落后 `quattro` 3742 个 commit。
- v4.5.1 是否即将发布：只看到 `v4-5-1` 分支，没有 tag 或 release。
- Omarchy ISO 安装器创建的完整 btrfs 子卷列表（例如是否有 `@pkg`）：安装器不在本仓库。本文只从 factory reset 代码看到 `@`、`@home`、`@log`、`@factory`、`/.snapshots`、`swap`。
- HM `programs.codex` 是否有专门写 AGENTS.md 的选项未查证；DSH 是否读取 `~/.agents/AGENTS.md` 只有 Omarchy 的说法。
- HM 把 session 变量写进 `.zshenv`、`ssh host cmd` 在本仓两台机器上能拿到完整 PATH：凭经验推断，没有实测。
- 没有 Time Machine 目的地时，`tmutil localsnapshot` 是否创建快照：没有执行，因为会改系统状态。
- `services.snapper` 的选项名是在本机 store 里一份 nixpkgs 的 `nixos/modules/services/misc/snapper.nix` 中确认的，没有确认这份就是 `flake.lock` 锁定的 `19cfded7`。
- DHH 没有公开说过 bash 与 agent 有关的取舍；Omarchy 选 bash 的 agent 相关理由（如果有）无法核实。
- `codex --approve-for-me` 在 Codex 中的确切语义没有查证；本文只说明 Omarchy 用它当免审批模式。
