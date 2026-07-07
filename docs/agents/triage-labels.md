# 分诊标签（Triage Labels）

这些 skill 用五个规范化的分诊角色来表达状态。本文件把这些角色映射到本仓问题追踪器实际使用的标签字符串。

| mattpocock/skills 中的标签 | 本仓追踪器中的标签 | 含义                      |
| -------------------------- | ------------------ | ------------------------- |
| `needs-triage`             | `needs-triage`     | 维护者需要评估该 issue    |
| `needs-info`               | `needs-info`       | 等待报告者补充信息        |
| `ready-for-agent`          | `ready-for-agent`  | 已完全明确，可交 AFK 代理 |
| `ready-for-human`          | `ready-for-human`  | 需要人工实现              |
| `wontfix`                  | `wontfix`          | 不予处理                  |

当某个 skill 提到某个角色（例如“打上 AFK-ready 分诊标签”）时，使用本表对应的标签字符串。对本仓的本地 markdown 追踪器而言，标签写在 issue 文件顶部附近的 `Status:` 行。

按你实际使用的词汇修改右侧列。
