# flake nixConfig 无法消费共享文件：为何缓存 / 公钥在两处重复

## 背景

`flake.nix` 的 `nixConfig.extra-substituters` / `extra-trusted-public-keys`（首次 bootstrap 时让
nix 走这些 cache）与 `modules/shared/nix.nix` 的 `nix.settings`（系统稳态）之间，有 4 组 cache
URL + 可信公钥逐字重复。直觉上想抽一个 `lib/caches.nix` 单源化两处。

实测（Lix，本仓）证明不行：nixConfig 的值一旦源自 `import` 的文件，flake 配置读取阶段拒绝，报
`error: flake configuration setting 'extra-substituters' is a thunk`。

| 写法 | 结果 |
|------|------|
| 内联字面量列表 | ✅ |
| 顶层 `let` 绑定的字面量列表 | ✅ |
| `let c = import ./caches.nix; in ... = c.urls` | ❌ is a thunk |
| import 投影 `++ 额外项` | ❌ is a thunk |

即 flake 配置读取器只 force 廉价内联字面量，拒绝任何源自 `import` 文件的值。`lib/caches.nix`
永远喂不进 nixConfig。

## 决定

不抽共享 caches 模块，接受这份跨 nixConfig ↔ nix.settings 的重复。两点理由：

1. **seam 被 Lix 禁**：如上，nixConfig 无法消费 import 文件。
2. **另一侧已单源**：`modules/shared/nix.nix` 是所有 host 的唯一 substituters 定义（mihomo-gateway
   用 `lib.mkBefore` 加性合并、非拷贝）。只喂 nix.settings 的 `lib/caches.nix` 会是单消费者的浅间接层
   （inline 回去复杂度即消失，过不了 deletion test）。

改用轻量记账：`flake.nix` nixConfig 与 `modules/shared/nix.nix` 各留一行互指注释（bootstrap 子集、
无法单源、见本 ADR），把「静默 rot」转成「显式已知」。不建 CI guard —— 公钥近乎不轮换，为低频风险
建机器不划算。

## 关联

- `flake.nix` —— nixConfig bootstrap 列表
- `modules/shared/nix.nix` —— nix.settings 稳态真源
- `AGENTS.md` —— 「Binary caches are in modules/shared/nix.nix; flake.nix.nixConfig is only bootstrap」
