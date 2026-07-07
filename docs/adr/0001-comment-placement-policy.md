# 注释放置政策：局部 WHY 就地、档案级进 ADR、架构进 AGENTS.md

## 背景

本仓 `.nix` 注释约 207 / 2675 行，绝大多数是不可省略的 WHY（CVE、上游 issue、
反直觉决策），而非复述代码的 WHAT slop。真正的痛点是少数长注释块的**密度**，
以及同一条 WHY 在 inline 与 `AGENTS.md` 的**重复**。

`oh-my-openagent` 自带 `@code-yeongyu/comment-checker` 并在编辑时自动运行，但其
0.8.0 的 tree-sitter 语法包不含 `nix`，故对本仓 `.nix` 注释零约束。

## 决定

按类型放置注释，每条 WHY 只留一个真源：

- **WHAT**（复述代码）：删。
- **局部 WHY**（绑定某一行的值 / workaround）：**就地保留**，压到 1-3 行；inline 是唯一真源。
- **档案级 WHY**（反复要查、带退出条件或跨文件耦合，如 pnpm pin、Wayland/fcitx IME）：
  完整来龙去脉写进 `docs/adr/`，inline 与 `AGENTS.md` 只留一行指针。
- **架构 WHY**（跨文件叙事）：进 `AGENTS.md` / `README.md`；`AGENTS.md` 只留
  架构 + 约定 + 指针，不复述局部 WHY。

## 权衡

就地性优先于"代码看起来干净"——局部 WHY 一旦搬离代码会更快 stale，且编辑该行的人
失去线索。密度问题用"就地压缩 + 少数档案级外移"解决，而非把注释全量搬进文档。

## 关于 nix 护栏

comment-checker 不支持 `.nix`，短期内不自建检查（自定义 lint 噪声大、给上游加
grammar 不可控）。个人 config、低频改动，靠本政策 + 人肉 review 即可。若日后
误删 / 回潮频繁，再重新评估。

原本 `pkgs/comment-checker` 自制包已移除：omo 插件自带全平台 vendored 二进制，在
NixOS 上经 `programs.nix-ld`（已启用）直接运行（实测 `libgcc_s`/glibc 由 nix-ld
默认库集解析），PATH 供给冗余；本仓 `.nix` 又零约束。TS/Go 等 repo 的检查完全由
插件自供，无需再维护该包。若将来 vendored 二进制链新库致 nix-ld 缺 `.so`，补一行
`programs.nix-ld.libraries` 即可。
