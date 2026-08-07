# Nixpkgs / Cherry Studio 过时用法审计（2026-08-07）

## 结论

| 平台 / 项目 | 审计前 | 当前上游 | 处理 |
|---|---:|---:|---|
| macOS Homebrew cask | 2.0.0 | 2.0.2 | 已更新 `homebrew-cask` lock，现为 2.0.2。 |
| Linux `nixpkgs-pnpm-pin` | 1.9.9 | nixpkgs 1.9.11；Cherry 上游 2.0.2 | 已将 pin 更新到 nixpkgs 的 1.9.11 提交；overlay 仍需保留。 |
| 主 nixpkgs `cherry-studio` | 1.9.11 | nixpkgs master 仍为 1.9.11 | 当前不可直接替代 pin：评估会因 insecure pnpm 与 EOL Electron 被拒绝。 |
| Home Manager / nix-darwin / NixOS API | — | — | 未发现由官方源码或本仓库评估警告确认的弃用用法。 |

## Cherry Studio 详情

### 上游版本

Cherry Studio 最新正式版本为 [2.0.2](https://github.com/CherryHQ/cherry-studio/releases/tag/v2.0.2)。其官方 `package.json` 使用 Electron 41.8.0 与 pnpm 11.8.0：

- [v2.0.2 package.json](https://github.com/CherryHQ/cherry-studio/blob/v2.0.2/package.json#L320)
- [v2.0.2 packageManager](https://github.com/CherryHQ/cherry-studio/blob/v2.0.2/package.json#L449)

### macOS

Darwin 配置使用 Homebrew cask，不经过 Nixpkgs overlay。审计时仓库锁定 cask 为 2.0.0，而 Homebrew 当前 cask 已为 2.0.2；已更新 `homebrew-cask` lock 到 `dfd043123b2e59d80163982b9f75f7dcde56e2ce`。

证据：

- [Homebrew `cherry-studio` cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/c/cherry-studio.rb)
- 本仓库 `modules/desktop/darwin.nix`
- 本仓库 `flake.lock`

### Linux

Linux 的 `pkgs.cherry-studio` 由 `overlays/default.nix` 覆盖，来自独立 `nixpkgs-pnpm-pin`。

审计结果：

1. 旧 pin `49a4bd…` 提供 Cherry Studio 1.9.9。
2. nixpkgs 提交 [`4c5fd5a`](https://github.com/NixOS/nixpkgs/commit/4c5fd5ac81ed3f63654e295d49552ca1dbc65447) 提供 1.9.11。
3. 对该提交执行 dry-run，只需从缓存下载 Cherry Studio 成品：95.43 MiB 下载、336.84 MiB 解包，无本地 derivation 构建。
4. 已把 `nixpkgs-pnpm-pin` 更新到该提交，当前 Linux 配置解析为 Cherry Studio 1.9.11。

仍不能删除 pin。仓库主 nixpkgs `b7c2ada…` 虽也提供 1.9.11，但：

- `pnpm_10_29_2` 已因 CVE-2026-48995、CVE-2026-50014/15/16/17、CVE-2026-50573、CVE-2026-55699、CVE-2026-59194/95/96 标记 insecure；
- Electron 40.10.5 已因 Electron 40 EOL 标记 insecure；
- 正常求值 `cherry-studio.drvPath` 会被 Nixpkgs 拒绝；
- 临时允许 insecure 后 dry-run 显示 5 个 derivation 需本地构建，并需下载约 1.55 GiB。

因此主 nixpkgs 目前不是更安全或更省构建的替代项。旧 revision 未携带后来加入的 insecure 元数据，但仍使用 pnpm 10.29.2 与 Electron 40.10.3；pin 只保留可评估性和缓存命中，不代表这些依赖已恢复安全支持。

退出条件：Nixpkgs 将 Cherry Studio 更新到无 insecure 依赖的版本后，再执行 dry-run；缓存可接受时删除 overlay 与 `nixpkgs-pnpm-pin`。

官方来源：

- [Nixpkgs 当前 Cherry Studio 定义](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ch/cherry-studio/package.nix)
- [Nixpkgs 1.9.9 → 1.9.11 PR](https://github.com/NixOS/nixpkgs/pull/533932)
- [Cherry Studio 2.0.2 release](https://github.com/CherryHQ/cherry-studio/releases/tag/v2.0.2)

## 其他审计结果

- `just eval`：`awesome-pc`、`mihomo-gateway`、`ovh-ks-5` 均通过，无弃用警告。
- nixd 诊断未发现配置 API 错误；仅两份自动生成的 `hardware-configuration.nix` 报未使用 `pkgs` 形参，不是过时 API，也未手改生成文件。
- 未发现旧 Home Manager 形态：`programs.git.userName/userEmail/extraConfig`、旧 SSH 配置、显式 `enableFishIntegration = true`。
- 未发现已移除的 Android 配置：`programs.adb`、`adbusers`、`android-udev-rules`。
- `services.desktopManager.plasma6.enable`、`services.displayManager.sddm.wayland.enable`、`hardware.graphics.enable` 仍存在于当前 Nixpkgs 模块树。
- 未对其余 flake inputs 做无差别升级；本次只更新与 Cherry Studio 直接相关的 pin 和 Homebrew cask。

## 本次改动

- `flake.nix`：Linux Cherry pin 更新到 1.9.11 提交，修正退出条件注释。
- `flake.lock`：更新 `nixpkgs-pnpm-pin` 与 `homebrew-cask`。
- `overlays/default.nix`、`AGENTS.md`：修正 workaround 的真实原因和退出条件。
