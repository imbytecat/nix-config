# AI 模型目录：每模型一节点（id+元数据）+ provider 间非对称 keying

## 背景

给 claude/gpt/gemini 补「像 furtherverse 一样」的元数据（name/reasoning/modalities/limit）时，
`home/ai-catalog.nix` 面临结构选择。原状分两处：`models` 别名表（role→bare id，如 `opus =
"claude-opus-4-8"`）+ `furtherverseModels`（id→元数据）。

若第一方也沿用两层（别名表 + 独立元数据表 keyed by id），同一个 id 字面量会在别名 value 与元数据
key 各出现一次，与 catalog「唯一真源、防漂移」的本分冲突，得再加断言兜底。

## 决定

**合成一层，零重复。** 第一方（anthropic/openai/google）每模型一个 **nick-keyed 节点**
`{ id + 元数据 }`；opencode adapter 按 `.id` 投影成 `provider.<id>.models`，并在 `let` 里用本地 id
简写引用（`opus`/`gpt`/… 仅可读性糖，非第二别名层）。nick 写错时 Nix 直接 eval 报错，天然防漂移，
无需断言。

**furtherverse 保持 id-as-key 不动。** 由此产生 provider 间**非对称 keying**——第一方
`nick → { id; meta }`、furtherverse `id → { meta }`。这是刻意的，不是遗漏。

## 权衡

- **合一层 vs 两层+断言**：选合一层。零重复、免 drift guard；代价是 `opencode.nix` ~18 处引用一次性
  从 `catalog.models.X` 改为本地简写。
- **非对称 vs 统一 nick**：选非对称。furtherverse 模型无语义角色、按全名临时选（TUI 里挑）；给它 9 个
  模型硬编 nick，其中 8 个从不按角色引用，nick 纯仪式且要改 atlas/sisyphus-junior/writing 3 处引用。
  「第一方按角色引用 → nick-key，自托管按 id 临时选 → id-key」这条区分是有意义的。
- **加 models 块的语义**：对已知 provider 加 `provider.<id>.models` 是**合并/覆盖**（models.dev 其它
  模型照常可选），非限制；要「只留这些」得另用 `whitelist`（本仓未用）。故补元数据是纯增益、无破坏。

未来若有人想「统一」两种 keying：先读本条——不对称是设计，不是待清理的 churn。

## 关联

- `home/ai-catalog.nix` —— `anthropicModels`/`openaiModels`/`googleModels`（nick-key）+
  `furtherverseModels`（id-key）
- `home/dev/ai/opencode.nix` —— `projectMeta`/`byNick` 投影 + 本地 id 简写
- `CONTEXT.md` —— 「模型目录」
