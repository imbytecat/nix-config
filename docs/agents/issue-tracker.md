# 问题追踪：本地 Markdown

本仓的 Issue 与 PRD 以 markdown 文件形式存放在 `.scratch/` 下。

## 约定

- 一个 feature 一个目录：`.scratch/<feature-slug>/`
- PRD 为 `.scratch/<feature-slug>/PRD.md`
- 实现 issue 为 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 开始编号
- 分诊状态记录在每个 issue 文件顶部附近的 `Status:` 行（角色字符串见 `triage-labels.md`）
- 评论与对话历史追加到文件底部的 `## Comments` 标题下

## 当某个 skill 说“发布到问题追踪器”时

在 `.scratch/<feature-slug>/` 下新建文件（目录不存在则创建）。

## 当某个 skill 说“拉取相关工单”时

读取所引用路径的文件。用户通常会直接给出路径或 issue 编号。

## Wayfinding 操作

供 `/wayfinder` 使用。**map（地图）**是一个文件，每个工单对应一个 **child（子）** 文件。

- **Map**：`.scratch/<effort>/map.md` —— 承载 Notes / Decisions-so-far / Fog 正文。
- **Child ticket（子工单）**：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 开始编号，正文写问题。`Type:` 行记录工单类型（`research`/`prototype`/`grilling`/`task`）；`Status:` 行记录 `claimed`/`resolved`。
- **Blocking（阻塞）**：顶部附近一行 `Blocked by: NN, NN`。当所列的每个文件都为 `resolved` 时，该工单解除阻塞。
- **Frontier（前沿）**：扫描 `.scratch/<effort>/issues/`，找出 open、未阻塞且未认领的文件；按编号取第一个。
- **Claim（认领）**：动工前先把 `Status:` 设为 `claimed` 并保存。
- **Resolve（解决）**：在 `## Answer` 标题下追加答案，把 `Status:` 设为 `resolved`，然后往 `map.md` 的 Decisions-so-far 追加一个上下文指针（gist + 链接）。
