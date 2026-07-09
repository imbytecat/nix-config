# nixpkgs-pnpm-pin：为绕 pnpm CVE 的 cache miss 而钉住的 nixpkgs revision

## 背景

nixpkgs 自 2026-06-27 起把构建期 pnpm 10.29.2 标记为 insecure（CVE）。下游
electron-builder < 26.8.2 的包无法迁到修复版 pnpm（pnpm#10601），被迫连坐；
hydra 拒绝构建 insecure 派生，导致这些包的 binary cache 全 miss。stable 通道
也无法规避（cherry-studio 1.7.9 依赖 insecure 的 electron-38）。

## 决定

新增 flake input `nixpkgs-pnpm-pin`，pin 到被标记 insecure 前最后一个仍有 hydra
cache 的 revision（`49a4bd0573c376468dd7996ddb6f9fa31d8c4d97`）。`overlays/default.nix`
从该 input `inherit` 受影响的包，当前为 `cherry-studio`。

不采用 `permittedInsecurePackages`（会在本机重新构建、仍 cache miss，且放宽安全
边界），也不手工打包这些应用。

## 退出条件

某个包在上游摆脱 insecure pnpm 后，将其从 `overlays/default.nix` 的 `inherit`
移出；`inherit` 列表清空后，删除 `nixpkgs-pnpm-pin` input 本身。

## 进展

- 2026-07-09：`vue-language-server`（主 nixpkgs 3.3.6）已在上游摆脱 insecure pnpm，
  从主 nixpkgs eval 干净，移出 `inherit` 改回主 nixpkgs。`cherry-studio`（主 nixpkgs
  1.9.11）仍连坐 `pnpm-10.29.2`，pin 及 input 保留。

## 关联

- `flake.nix` —— input 声明
- `overlays/default.nix` —— `inherit` 受害包
- `AGENTS.md` —— agent 操作约束（勿加 `permittedInsecurePackages` / 勿手工打包）
