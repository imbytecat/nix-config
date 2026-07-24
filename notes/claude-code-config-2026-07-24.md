# Claude Code 配置审计（2026-07-24）

访问日期：2026-07-24。审计对象：`home/dev/agents/claude-code.nix`；审计后已按隐私优先方案修改配置，下表保留修改前状态。

## 结论摘要

- 当前锁定并实际运行的是 Claude Code `2.1.218`；`llm-agents.nix` 的锁定包和本机 `claude --version` 一致。[官方 CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- **Fable 有独立 family 配置**：把 `catalog.models.fable.id` 放进 `env.ANTHROPIC_DEFAULT_FABLE_MODEL`。它控制 `fable` alias，并帮助 Claude Code 在第三方部署中识别 Fable；不要挤占 Opus/Sonnet/Haiku 的映射。[模型配置](https://code.claude.com/docs/en/model-config#environment-variables)
- 主会话默认模型仍由顶层 `model`、`ANTHROPIC_MODEL`、`--model` 或会话内 `/model` 控制。`ANTHROPIC_DEFAULT_FABLE_MODEL` 只定义 family alias，不会自动把主会话或子代理切到 Fable。子代理继续由 `CLAUDE_CODE_SUBAGENT_MODEL` 等独立控制。[模型选择优先级](https://code.claude.com/docs/en/model-config#setting-your-model)
- 当前最需要修正的旧配置不是“再堆开关”，而是：`effortLevel = "max"` 已不属于 settings 接受值；`includeCoAuthoredBy` 已弃用；`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 会直接让已启用的 gateway model discovery 不运行。

## 修改前配置逐项对照

| 当前项 | 分类/状态 | 结论 |
|---|---|---|
| `effortLevel = "max"` | settings 顶层，当前值无效 | 官方仅接受 `low`、`medium`、`high`、`xhigh`；`max` 是会话级值。若确实要每次强制 max，改放 `env.CLAUDE_CODE_EFFORT_LEVEL = "max"`，但它会覆盖 `/effort` 和 skill/subagent effort；更稳妥的持久默认是顶层 `effortLevel = "xhigh"`。 |
| `permissions.defaultMode = "bypassPermissions"` | settings 顶层，稳定但高风险 | 与网关无关；仅在明确接受无确认执行时保留。 |
| `skipDangerousModePermissionPrompt = true` | settings 顶层，稳定但高风险 | 与网关无关；它只记录已接受危险模式提示。 |
| `includeCoAuthoredBy = false` | settings 顶层，已弃用 | 删除；现有 `attribution` 已完整覆盖并优先于它。 |
| `attribution` | settings 顶层，稳定 | 保留。空 `commit`/`pr` 已关闭提交和 PR 归因。 |
| `env.ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` | settings `env`，稳定 | 保留；新增独立的 `ANTHROPIC_DEFAULT_FABLE_MODEL`，不要混用 family。 |
| `env.CLAUDE_CODE_SUBAGENT_MODEL` | settings `env`，稳定 | 保留；当前强制所有 subagent、agent team 和 workflow agent 使用 Sonnet。 |
| `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY` | settings `env`，官方公开 | 保留的前提是网关实现 `/v1/models` 且希望 picker 自动刷新。它与 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 冲突，后者会阻止 discovery。 |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | settings `env`，官方兼容开关 | 仅在网关因 `anthropic-beta`、`context_management` 或 beta tool 字段报 `400` 时保留。实测当前网关在清空该变量后可完成 Sonnet 5 1M 请求，因此不应无条件长期禁用。 |
| `ENABLE_TOOL_SEARCH = "false"` | settings `env`，稳定但冗余 | 非官方 host 默认就关闭 MCP tool search。只有确认网关完整转发 `tool_reference` 时才设为 `true`。 |
| `CLAUDE_CODE_ATTRIBUTION_HEADER = "0"` | settings `env`，官方公开 | 可保留；网关会重排 system blocks 或跨会话按完整请求体缓存时有价值。自 v2.1.181 起 attribution block 在同一会话内已稳定，不再是所有网关的必需项。 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"` | settings `env`，官方公开 | 二选一：要隐私/禁外联就保留并删除 model discovery；要 gateway picker 自动刷新就删除它。当前同时设置自相矛盾。 |
| `DISABLE_AUTOUPDATER`、`DISABLE_INSTALLATION_CHECKS` | package wrapper 已设置 | 当前 `llm-agents.nix` 包装器已注入，两项在 settings 中重复，可删除。 |
| `cleanupPeriodDays = 90` | settings 顶层，稳定 | 保留；本地会话数据清理周期。 |

## Fable 接入建议

最小、语义正确的 family 映射：

```nix
ANTHROPIC_DEFAULT_FABLE_MODEL = catalog.models.fable.id;
```

这让 `/model fable` 明确解析到目录中的 `claude-fable-5`。不需要同时配置 `ANTHROPIC_CUSTOM_MODEL_OPTION`：当前 ID 是 Claude Code 已认识的标准 Fable ID，且已开启 gateway discovery。只有网关使用非标准 ID、或 discovery 不可用时，才需要 custom picker 项：

```nix
ANTHROPIC_CUSTOM_MODEL_OPTION = catalog.models.fable.id;
ANTHROPIC_CUSTOM_MODEL_OPTION_NAME = catalog.models.fable.name;
```

若希望启动即使用 Fable，再单独设顶层 `model = "fable"`；若只想手动选择，不设 `model`。当前 `CLAUDE_CODE_SUBAGENT_MODEL = catalog.models.sonnet.id` 不受影响，因此可以保持“主会话 Fable、子代理 Sonnet”。

### 网关下的 1M 上下文

实测当前配置：

- `/model fable` 实际调用 `claude-fable-5`，请求成功，但 Claude Code 按 `200000` context、`64000` max output 记账。
- `claude-fable-5[1m]` 请求成功，并按 `1000000` context 记账。
- `/model sonnet` 同样按 `200000` context 记账；`sonnet[1m]` 在清空 `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` 后请求成功并按 `1000000` 记账。

这符合官方说明：`ANTHROPIC_BASE_URL` 指向 gateway 时，Claude Code 无法自动确认扩展上下文，需用 `[1m]` 选择。若要让 family alias 始终使用目录声明的 1M，可在 Claude Code adapter 中给 Fable/Opus/Sonnet 的模型 ID追加 `[1m]`；Claude Code 会据此调整 compaction 窗口。先确保网关确实支持对应模型的 1M。

### UI 与子代理

`/model fable` 是主会话切换；Fable family 映射不会改变子代理。`CLAUDE_CODE_SUBAGENT_MODEL` 优先于 agent frontmatter 和每次 Agent tool 的 `model` 参数；若希望各 agent 自己选模型，应改成 `inherit`，而不是 Fable。

## 顶层键、env 键、shell-only、CLI 区分

- 顶层 settings：`model`、`effortLevel`、`permissions`、`attribution`、`cleanupPeriodDays`、`autoUpdatesChannel`、`availableModels` 等；官方完整表见 [settings reference](https://code.claude.com/docs/en/settings#available-settings)。
- `settings.json.env`：任意要由 Claude Code 启动时注入的字符串环境变量；settings 文件值会覆盖继承自 shell 的同名值。[env precedence](https://code.claude.com/docs/en/env-vars#precedence)
- 仅 shell 环境变量：`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_API_KEY`、`ANTHROPIC_MODEL` 等也可放 shell；本仓库注释说明 endpoint/token 由 fish `op-env` 注入，因此不要把密钥写入 Nix/settings。
- CLI：`claude --model <alias|name>` 是启动时选择；`/model` 是会话内命令；`--settings` 是临时 settings 文件。CLI 优先级由官方模型配置页定义。

## 中文社区线索

截至访问日，LinuxDO 搜索结果未提供可稳定引用的官方事实页面；社区帖子只能作为“网关需要自定义 model ID / Fable 映射”线索，不能证明任何环境变量。本文所有可执行结论均回溯到 Anthropic Claude Code 官方文档或官方 GitHub CHANGELOG；未把 LinuxDO 内容当作证据。

## 最小建议清单

1. **新增** `env.ANTHROPIC_DEFAULT_FABLE_MODEL = catalog.models.fable.id`；Fable 不放进 Opus/Sonnet/Haiku 映射。
2. **修正** `effortLevel = "max"`：推荐改为顶层 `"xhigh"`；若坚持全局 max，则移到 `env.CLAUDE_CODE_EFFORT_LEVEL = "max"`，并接受它覆盖会话/agent effort。
3. **删除**已弃用的 `includeCoAuthoredBy`；保留 `attribution`。
4. **解决冲突**：gateway discovery 与 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 不能同时生效。当前配置若要 discovery，应删除后者。
5. **按故障启用兼容开关**：`CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` 只在网关实际报 beta 字段错误时使用；`ENABLE_TOOL_SEARCH=true` 只在网关支持 `tool_reference` 时使用。
6. 当前 `llm-agents.nix` wrapper 已设置自动更新禁用；隐私优先方案仍在 settings 中显式保留 `DISABLE_AUTOUPDATER=1`，仅删除无关的安装方式检查重复项。
7. 若要实际利用目录声明的 1M context，为 Fable/Opus/Sonnet 选择带 `[1m]` 的模型名；当前不带后缀时实测按 200K 计算。

实施结果：已完成 Fable 独立映射和 1M 标记、`xhigh` 持久 effort、隐私流量限制、WebFetch 预检关闭、官方 marketplace 自动安装关闭，并保留显式自动更新禁用；gateway model discovery 因隐私策略移除。

来源（官方）：[settings](https://code.claude.com/docs/en/settings)，[environment variables](https://code.claude.com/docs/en/env-vars)，[model configuration](https://code.claude.com/docs/en/model-config)，[LLM gateways](https://code.claude.com/docs/en/llm-gateway)，[official CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)。