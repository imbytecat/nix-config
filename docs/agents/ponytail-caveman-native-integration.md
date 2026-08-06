# Ponytail / Caveman 原生集成调查

> 调查日期：2026-08-06。以本仓 `flake.lock` 为准：Ponytail 锁定 [`16f29800fd2681bdf24f3eb4ccffe38be3baec6b`](https://github.com/DietrichGebert/ponytail/commit/16f29800fd2681bdf24f3eb4ccffe38be3baec6b)，Caveman 锁定 [`ec83e5bace4c20484d704dea21e12fc4eb94e9aa`](https://github.com/JuliusBrussee/caveman/commit/ec83e5bace4c20484d704dea21e12fc4eb94e9aa)。先前笔记中的 Ponytail `3f05e2` 不是当前锁定值。调查时两仓 `main` 恰好仍分别指向这两个提交，但下文只按完整 SHA 判断；未来 `main` 漂移不改变结论依据。

## 结论矩阵

| 组合 | 锁定版本实际提供 | 性质 | 结论 |
|---|---|---|---|
| OMP/Pi × Ponytail | 根 `package.json` 的 `pi.extensions`/`pi.skills`，`pi-extension/index.js` | **真实可执行 Pi 扩展**；同时带技能 | 首选。扩展注册命令与 `input`、`session_start`、`agent_start/end`、`before_agent_start` 事件，按当前模式改写 system prompt。不是只复制提示词。 |
| OMP/Pi × Caveman | 根技能目录与 `AGENTS.md`；没有 `omp`/`pi` manifest，也没有 Pi extension | **仅指令型回退** | 可让 OMP 从技能目录加载 `SKILL.md`，但没有 `/caveman` 原生命令、会话模式状态或事件 hook；OMP 的技能命令是 `/skill:caveman`。 |
| Codex × Ponytail | `.codex-plugin/plugin.json` + 三类 lifecycle hook + `skills/` | **完整原生 Codex 插件** | 首选。`SessionStart` 激活并注入规则，`SubagentStart` 注入子代理，`UserPromptSubmit` 跟踪模式。需要 Node、hook 审核/信任及可写插件数据目录。 |
| Codex × Caveman | `plugins/caveman/.codex-plugin/plugin.json` 只声明技能；根 `.codex/hooks.json` 另有项目级 `SessionStart` hook；官方安装器实际运行 `npx skills add ... -a codex` | **技能插件与项目 hook 分离** | manifest 是真实 Codex 插件格式，但不是完整可安装集成：仓库没有 Codex marketplace，manifest 也未打包 hook。官方 Codex 安装路径仍是按会话启用的指令技能；根 hook 只有在受信任的 Caveman checkout/复制出的 `.codex` 层中才会执行。 |

## 1. OMP/Pi

### 1.1 Ponytail：原生扩展，不是 instruction-only

锁定源码的根 [`package.json`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/package.json) 声明：

```json
"pi": {
  "extensions": ["./pi-extension/index.js"],
  "skills": ["./skills"]
}
```

OMP 当前仍接受 legacy `pi.extensions` manifest；显式 `extensions:` 路径如果指向 package 目录，会读取 `package.json#omp.extensions`，再回退到 `pi.extensions`。扩展包旁边的 `skills/` 由 `omp-plugins` provider 一并发现。证据：OMP 的 [`extension-loading.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/extension-loading.md) 与 [`skills.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/skills.md)。

[`pi-extension/index.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/pi-extension/index.js) 的真实运行面：

- 注册 `/ponytail`，支持 `off|lite|full|ultra`、`status`、`default <mode>`；另注册 review/audit/debt/gain/help 别名。
- `session_start` 从 OMP session entries 恢复模式，显示状态。
- `input` 识别停用命令。
- `agent_start`/`agent_end` 更新 UI 状态。
- `before_agent_start` 把 [`hooks/ponytail-instructions.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-instructions.js) 生成的当前等级规则附加到 system prompt。
- `pi.appendEntry("ponytail-mode", ...)` 将会话模式交给 OMP session store 持久化；插件源码目录无需可写。

OMP 扩展与宿主同进程、无沙箱，安装即信任代码；官方 loader 会 `realpath` 后动态导入，显式绝对路径和 symlink 都可用。见 [`extensions.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/extensions.md)、[`extension-loading.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/extension-loading.md)。

**不可变 Nix store：可直接使用。** 在 OMP 用户配置的 `extensions:` 中指向 Ponytail store 根目录即可；loader 从 store 读取扩展，技能 provider 读取同根 `skills/`。运行时写入发生在 OMP session state，以及可选的 `~/.config/ponytail/config.json`：[`ponytail-config.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-config.js) 的 `writeDefaultMode()` 只在 `/ponytail default ...` 时写该文件。若 home/config 只读，该命令失败，但当前会话模式和规则注入仍可工作。

### 1.2 Caveman：没有 Pi/OMP adapter

锁定源码根 [`package.json`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/package.json) 只有安装器元数据，没有 `omp` 或 `pi` 字段；官方 [`INSTALL.md`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/INSTALL.md) 的 agent matrix 也没有 Pi/OMP。仓库中的 JS lifecycle hooks 由 [Claude plugin manifest](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/.claude-plugin/plugin.json) 引用，不是 Pi 扩展，不能由 OMP 当作等价 adapter 加载。

可行回退：将 store 中的 `skills/` 加入 OMP `skills.customDirectories`，或把单个技能目录 symlink 到 OMP 的技能根。OMP 会加载 [`skills/caveman/SKILL.md`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/skills/caveman/SKILL.md)，由描述隐式匹配或通过 `/skill:caveman` 显式调用。此路径是 **instruction-only skill**：没有 `/caveman` alias、`pi.on(...)` 事件、持久模式或每轮强制注入。store 只需可读。

## 2. OpenAI Codex

### 2.1 宿主约束

Codex 官方规则：

1. 插件根必须有 `.codex-plugin/plugin.json`；`skills`、`hooks` 等 manifest 路径必须以 `./` 开头、相对插件根解析并留在根内。默认 hook 文件是 `hooks/hooks.json`，否则 manifest 可用 `hooks` 显式指定。[Package your plugin](https://developers.openai.com/plugins/build/plugins#package-and-distribute-plugins)
2. 启用插件不会自动信任 hook。常规路径是在 `/hooks` 审核；信任绑定当前 hook 定义 hash，内容变化后会跳过。用户层也可在 `config.toml` 的 `hooks.state.<key>.trusted_hash` 声明经过审核的固定 hash，定义变化时仍会 fail closed。[Hooks: review and trust](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks)、[Codex hook state](https://github.com/openai/codex/blob/main/codex-rs/config/src/hook_config.rs)
3. 项目 `.codex/config.toml`/`hooks.json` 只在项目受信任时加载；untrusted project 会跳过项目 config、hooks、rules。[Hooks: where Codex looks](https://learn.chatgpt.com/docs/hooks#where-codex-looks-for-hooks)、[config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
4. 插件 hook 获得只读代码定位变量 `PLUGIN_ROOT` 和可写数据目录 `PLUGIN_DATA`；兼容变量 `CLAUDE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_DATA` 也会设置。[Hooks: plugin-bundled hooks](https://learn.chatgpt.com/docs/hooks#plugin-bundled-hooks)
5. local marketplace 安装不会直接从源目录运行：宿主把插件复制到 `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/`，启用状态写入 `~/.codex/config.toml`。本地 marketplace 的 `source.path` 应相对 marketplace root；Git source 可用 `ref` 或 `sha`。[Package your plugin: marketplace metadata](https://developers.openai.com/plugins/build/plugins#marketplace-metadata)

因此，**Nix store 可作为 marketplace/source 的只读输入**。Codex 仍需要 store 外的真实可写安装 cache 与 `PLUGIN_DATA`；enable state 和经过审核的 hook trust hash 可以声明进 Nix 生成的 `config.toml`。

### 2.2 Ponytail：完整插件与三个 lifecycle hook

锁定 [`.codex-plugin/plugin.json`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/.codex-plugin/plugin.json) 同时声明 `"skills": "./skills/"` 与 `"hooks": "./hooks/claude-codex-hooks.json"`。hook manifest [`hooks/claude-codex-hooks.json`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/claude-codex-hooks.json) 注册：

- `SessionStart` → [`ponytail-activate.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-activate.js)：设置活动模式并输出规则上下文。
- `SubagentStart` → [`ponytail-subagent.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-subagent.js)：读取当前模式并向匹配的 subagent 注入规则。
- `UserPromptSubmit` → [`ponytail-mode-tracker.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-mode-tracker.js)：解析 `/ponytail`、等级切换和停用命令。

三条命令都调用 `node`，所以非交互 shell 的 `PATH` 必须包含 Node。它们使用 `${CLAUDE_PLUGIN_ROOT}`，Codex 官方兼容变量保证可解析。运行态由 [`ponytail-runtime.js`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/ponytail-runtime.js) 写到 `${PLUGIN_DATA}/.ponytail-active`；`/ponytail default ...` 另写 `~/.config/ponytail/config.json`。

Ponytail 自带 [`.agents/plugins/marketplace.json`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/.agents/plugins/marketplace.json)，但其中插件 source 明确写 `ref: "main"`。本仓改由 HM 生成指向固定 Nix input 的 local marketplace；激活时再把 HM cache symlink 落成真实可写目录，并在生成的 `config.toml` 中声明三条经过审核的 trust hash。Standalone Codex 无需 mutable clone、host install 或交互 `/hooks`；Orca managed `CODEX_HOME` 使用独立 trust store，首次同步新 plugin hook 仍需审核一次。上游定义变化后 hash 不匹配，hook 自动停用。

### 2.3 Caveman：技能插件、项目 hook、安装器三者不等价

锁定源码包含真正的 Codex manifest：[`plugins/caveman/.codex-plugin/plugin.json`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/plugins/caveman/.codex-plugin/plugin.json)。但它只声明 `"skills": "./skills/"`，没有 `hooks`，该 plugin root 下也没有默认 `hooks/hooks.json`。所以安装此 bundle 只获得指令技能和展示元数据，不会自动启用 Caveman 模式。

仓库根另有：

- [`.codex/config.toml`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/.codex/config.toml)：打开 `hooks`，兼容旧键 `codex_hooks`。
- [`.codex/hooks.json`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/.codex/hooks.json)：真实 `SessionStart` command hook，用 shell `echo` 输出一段 Caveman developer context。

该 hook 确实执行，但它是 **项目级 instruction injection hook**，不是 `plugins/caveman` bundle 的 lifecycle hook。只有 Codex 在受信任 Caveman checkout 中启动，或用户把这层复制/声明到自己的 user/project `.codex` 后，它才生效；它没有 `PLUGIN_DATA` 状态，也没有模式 tracker。

官方 [`INSTALL.md`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/INSTALL.md) 对 Codex 明确写 `npx skills add JuliusBrussee/caveman -a codex`，并标注 “Per-session: `/caveman`”。安装器 [`cli/install.js`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/cli/install.js) 的 Codex provider 也只进入通用 `installViaSkills()`，调用 `npx skills add`；不会复制根 `.codex/hooks.json`，也不会安装上述 plugin bundle。因此，Pinned Caveman 的常规 Codex 安装是 **instruction-only**，不是 lifecycle-plugin。

对于不可变 store，skills 仍直接 symlink 到 `$HOME/.agents/skills`。为提供 always-on 模式，本仓另生成一个只包含上游 `.codex/hooks.json` 的最小 `caveman` Codex plugin；这不是重写 hook，只是给上游分离的 hook 文件补上 plugin manifest，使它在普通 Codex 与 Orca 隔离的 managed `CODEX_HOME` 中都按 lifecycle plugin 加载。trust hash 继续锁定原始 hook 定义。

## 3. 推荐的声明式接入

1. **OMP + Ponytail：直接引用 store 根。** 在 OMP `extensions:` 中放入锁定 Ponytail 输出目录；由 `pi` manifest 同时加载扩展和 sibling skills。无需 `omp plugin install/link`，避免 `~/.omp/plugins`、lockfile 和 mutable clone。
2. **OMP + Caveman：只声明 skill directory。** 用 `skills.customDirectories` 指向锁定 Caveman `skills/`；接受 `/skill:caveman`/隐式触发，不伪装成不存在的 Pi extension。若要求 `/caveman`、状态条或每轮事件注入，当前上游缺 adapter，这是实际 blocker。
3. **Codex + Ponytail：HM local marketplace + 实体 cache。** `programs.codex.plugins` 生成固定输入的 marketplace、enable state 与 cache；激活后把 cache symlink 复制成 Codex 0.146 可识别、下次 HM 激活可清理的真实目录。`hooks.state` 声明三个固定 trust hash，Node 由现有开发环境提供；hash 变化时 fail closed。
4. **Codex + Caveman：skills + 最小 hook plugin。** skills 继续 symlink；用本地生成的 manifest 把上游 `.codex/hooks.json` 封装成 `caveman@home-manager`，避免把原有无 hooks 的 `plugins/caveman` manifest 误判成完整 lifecycle plugin。

## 4. HM 原生机制与 adapter seam（结论）

### 4.1 `programs.codex.plugins` 已覆盖什么

Home Manager 的通用 Codex module 已负责三件事：从 plugin derivation/path 生成 `home-manager` marketplace、在 `config.toml` 启用 `<plugin>@home-manager`，并把源链接到 `CODEX_HOME/plugins/cache/home-manager/<name>/<version>`。实现见 [`default.nix`](https://github.com/nix-community/home-manager/blob/master/modules/programs/codex/default.nix) 与 [`lib.nix`](https://github.com/nix-community/home-manager/blob/master/modules/programs/codex/lib.nix)；其测试只断言 cache 是 symlink 和文件可经 symlink 读取，没有启动 Codex 验证 installed 状态（[`plugins.nix`](https://github.com/nix-community/home-manager/blob/master/tests/modules/programs/codex/plugins.nix)）。

Codex 0.146 的实际约束更窄：同一份 config/marketplace 下，cache 根为 HM store symlink 时 `codex plugin list --json` 返回 `installed: []`；只把该 symlink 换成实体副本后，同一命令立即识别 `ponytail@home-manager`。因此 `materializeCodexPlugins` 不是重复 marketplace/enable 逻辑，而是 Home Manager link plumbing 与 Codex 0.146 installed detection 之间的 compatibility adapter。Codex 自身仍有未解决的 plugin symlink materialization 缺口（[openai/codex#24770](https://github.com/openai/codex/issues/24770)）；该 issue 主要讨论 plugin tree 内 symlink，不直接替代本仓对 cache 根 symlink 的实测。

### 4.2 两条架构轴

Ponytail 与 Caveman 不是「更大的 skill」，也不等于 Codex plugin 或 OMP extension。仓库统一称它们为 **behavior bundle（行为包）**：一个跨 agent 的行为产品，可包含默认规则、生命周期 hook、命令、状态和可选 skills。`plugin`、`extension`、`rule`、`hook`、`skill` 都只是各 host 的装载机制。

代码按两条正交轴组织：

| 目录 | 责任 |
|---|---|
| `home/dev/agents/bundles/` | 每个行为包独立拥有 pin-specific packaging、hook trust、OMP 投影与共享 skills；`default.nix` 是 plain-attr registry。 |
| `home/dev/agents/adapters/` | 把 registry 投影到 Codex、OMP 和 `~/.agents/skills`；不重新定义 Ponytail/Caveman 语义。 |

因此新增行为包只需新增一个 bundle 并注册；新增 agent 只需新增一个 adapter。实现没有引入 NixOS/Home Manager 自定义 option 或通用 plugin framework：registry 只是两个真实 bundle 与三个真实 adapter 之间的最小数据 seam。

### 4.3 当前投影

1. `bundles/ponytail.nix`：Codex 直接消费上游正式 plugin；OMP 直接引用仓库根 extension；skills 由两边 plugin 自带。
2. `bundles/caveman.nix`：Codex 用最小 manifest 封装上游 `.codex/hooks.json`；OMP 使用 always-apply rule 与 `/caveman` command；可运行 skills 导出到共享目录。
3. `adapters/codex-plugins.nix`：聚合 plugin source、trust hash 与 Codex 0.146 cache materialization。
4. `adapters/omp.nix`：聚合 `extensions` 与 bundle-owned `home.file`。
5. `adapters/skills.nix`：聚合 bundle skills 与 agent-browser、mattpocock 等 skill-only distribution。

Caveman 上游若把 hook 纳入正式 plugin，删除 wrapper；Codex/HM 若原生识别 cache symlink，删除 activation。行为包边界不变，只有对应 adapter 数据缩减。

搜索范围与负结果：Home Manager module/tests/issues、OpenAI Codex plugin/hooks issues、Ponytail/Caveman upstream，以及 GitHub 可索引公开 Nix configs；没有找到可直接复用并同时满足 pinned source、native lifecycle hook、Orca managed `CODEX_HOME` 和 declarative Home Manager 的实现。

## 一方证据索引

- Ponytail pinned：[`package.json`](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/package.json)、[Pi extension](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/pi-extension/index.js)、[Codex manifest](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/.codex-plugin/plugin.json)、[Codex hooks](https://github.com/DietrichGebert/ponytail/blob/16f29800fd2681bdf24f3eb4ccffe38be3baec6b/hooks/claude-codex-hooks.json)。
- Caveman pinned：[`package.json`](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/package.json)、[install guide](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/INSTALL.md)、[Codex skill manifest](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/plugins/caveman/.codex-plugin/plugin.json)、[project hook](https://github.com/JuliusBrussee/caveman/blob/ec83e5bace4c20484d704dea21e12fc4eb94e9aa/.codex/hooks.json)。
- OMP official：[`extensions.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/extensions.md)、[`extension-loading.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/extension-loading.md)、[`skills.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/skills.md)、[`plugin-manager-installer-plumbing.md`](https://github.com/can1357/oh-my-pi/blob/1e492d6ff9b8d4412591942b11fe06e1395ae80f/docs/plugin-manager-installer-plumbing.md)。
- Codex official：[plugin packaging](https://developers.openai.com/plugins/build/plugins)、[hooks](https://learn.chatgpt.com/docs/hooks)、[skills](https://learn.chatgpt.com/docs/build-skills)、[config/trust](https://learn.chatgpt.com/docs/config-file/config-reference)。
