# 领域文档（Domain Docs）

工程类 skill 在探索代码库时应如何消费本仓的领域文档。

## 探索前先读这些

- 仓库根目录的 **`CONTEXT.md`**，或
- 若存在，仓库根目录的 **`CONTEXT-MAP.md`** —— 它按每个上下文指向一个 `CONTEXT.md`。读取与主题相关的每一个。
- **`docs/adr/`** —— 阅读与你即将动工区域相关的 ADR。在多上下文仓库中，还要查看 `src/<context>/docs/adr/` 里按上下文划分的决策。

若这些文件都不存在，**静默继续**。不要指出它们缺失；不要一上来就建议创建。`/domain-modeling` skill（经由 `/grill-with-docs` 与 `/improve-codebase-architecture` 触达）会在术语或决策真正被敲定时惰性创建它们。

## 文件结构

本仓为**单上下文（single-context）**：仓库根目录一个 `CONTEXT.md` + `docs/adr/`。

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文（root 下存在 `CONTEXT-MAP.md`）布局 —— 仅供参考：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用术语表的词汇

当你的输出命名某个领域概念（在 issue 标题、重构提案、假设、测试名中）时，使用 `CONTEXT.md` 中定义的术语。不要漂移到术语表明确避免的同义词。

若你需要的概念还不在术语表里，这是一个信号 —— 要么你在发明项目并不使用的语言（请重新考虑），要么存在真实的空缺（记下来交给 `/domain-modeling`）。

## 标记 ADR 冲突

若你的输出与既有 ADR 矛盾，请显式指出而非默默覆盖：

> _与 ADR-0007（event-sourced orders）矛盾 —— 但值得重新讨论，因为……_
