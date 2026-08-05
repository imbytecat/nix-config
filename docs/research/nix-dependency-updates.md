# Nix 依赖更新研究

> 范围：仅基于 Nix/Nixpkgs 官方文档与源码、工具官方仓库、Renovate 官方文档。本文针对本仓库现状，不修改 Nix 配置或命令。

## 结论先行

- **不需要统一 `update all`。** `nix flake update` 只刷新 `flake.lock` 中的 flake inputs；它不会扫描或改写普通 `.nix` 中 `fetchurl`/`fetchFromGitHub` 的 `version`、`rev` 或 fixed-output `hash`。本仓库 `just update` 当前调用它，边界应保持清晰：按输入选择性更新，包源另走包级流程。
- **不应把三个本地包变成 flake inputs 或 NUR。** 它们是本仓库自有 package 定义，且只需少量 source pin；转成 input/NUR 会增加锁文件、overlay 接线和第三方供应链层。NUR 官方明确说包“不经任何 Nixpkgs 成员审查”，定位是社区包分发，不是本地 fixed-output 更新器。
- **下一步最小改动：只把可机械更新的 Orca 暴露为 flake package output，再由 nix-update 生成候选 diff。** Rime、字体和 kexec 保持人工门槛；先不增加 updater 脚本、nvfetcher、NUR 或额外 flake input。

## 1. `nix flake update` 职责边界

Nix 官方手册把命令定义为 “update flake lock file”，并说明默认更新全部 inputs，也可传入 input 名称；相关 `nix flake lock` 只添加缺失输入、不会更新已有锁项，因此更安全（Nix 2.34.9 文档：[官方手册](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-update)）。

本仓 `flake.nix` 的 inputs 包括 nixpkgs、home-manager、nix-darwin、工具 flake 和非 flake GitHub 资源；`just update` 即 `nix flake update`，`just up input` 是选择性更新。该命令只触碰 `flake.lock`：不会发现 `pkgs/orca-ide/default.nix` 的 GitHub release，不会为 `fetchurl` 重新取 hash，也不会改变四类普通资源。

建议：日常使用 `just up nixpkgs` 或一次只更新相关 input；只有有意接受全套 flake 变更时才用 `just update`。无需另造“统一 update all”。

## 2. 工具定位与限制

### nix-update 与 `passthru.updateScript` / nix-update-script

[nix-update 官方 README](https://raw.githubusercontent.com/Mic92/nix-update/main/README.md) 定义其用途是更新 Nix package 的版本/source hash，支持 GitHub 等 release 检测、固定输出依赖 hash、flake outputs，以及运行包的 `passthru.updateScript`。它默认倾向 stable release；可 `--version=skip` 只更新 source hash，也可 `--use-update-script` 执行既有脚本。它是包级 updater，不是 flake lock 更新器；非标准下载 URL、同一 derivation 多个 FOD、覆盖发布 tag 都需要人工参数或自定义脚本。

Nixpkgs 的更新脚本协议以 `passthru.updateScript` 暴露“如何更新”的入口；[官方 update runner](https://github.com/NixOS/nixpkgs/blob/master/maintainers/scripts/update.nix) 按包选择并执行脚本。这里适合可判定的单包 release；脚本仍不能替人判断 ABI、许可证、供应链和运行时兼容性。

### nurl

[nurl 官方 README](https://raw.githubusercontent.com/nix-community/nurl/main/README.md) 的定位是“Generate Nix fetcher calls from repository URLs”。它可推断 `fetchFromGitHub`、`fetchurl` 等并计算 hash；支持 `--hash`、`--expr`。它是**生成/预取辅助工具**，不会跟踪版本、编辑包文件或评估升级风险；而且 README 警告 `--overwrite` 不验证会改变 hash 的覆盖项。因此适合手动升级 hash，不适合作为统一自动更新器。

### nvfetcher

[nvfetcher 官方 README](https://raw.githubusercontent.com/berberman/nvfetcher/master/README.md) 说明它通过 TOML 定义 source/fetch，结合 nvchecker，生成 `_sources/generated.nix/json`，维护版本与预取 SHA256。它要求引入生成文件和 TOML 元数据；支持 GitHub release、git 最新 commit、URL 等，但输出生成式结构。对本仓三个小而异质的包，为它们引入整套生成目录会比直接维护三处表达式更复杂；尤其 LTS 同 tag 覆盖与破坏性安装镜像仍需人工策略。

### Renovate Nix manager

[Renovate 官方 Nix manager 文档](https://docs.renovatebot.com/modules/manager/nix/) 标明 Nix manager **beta、默认关闭**，默认匹配 `flake.nix`，数据源是 `git-refs`；支持 `flake.lock` lock-file maintenance 和 input updates，锁文件维护委托给底层包管理器。它主要覆盖本仓 flake inputs，不会自动理解三个普通包表达式里的 release/hash 语义；启用它也不等于自动构建、部署或批准破坏性变更。

### NUR

[NUR 官方 README](https://raw.githubusercontent.com/nix-community/NUR/master/README.md) 定位为社区驱动的包表达式聚合；包由各贡献者负责，**不经任何 Nixpkgs 成员审查**，并提醒 NUR 不定期检查仓库恶意内容。NUR 可通过 flake overlay/legacyPackages 接入，但它解决“分发他人包”，不是本仓库 source pin 更新。三个本地包不应迁移到 NUR。

## 3. 本仓四类依赖映射

| 类别 | 当前定义 | 更新策略 | 自动化边界 |
|---|---|---|---|
| Orca GitHub release | `pkgs/orca-ide/default.nix`：`version = 1.4.170`，`fetchurl` 指向 `stablyai/orca/releases/download/v${version}/orca-linux.AppImage`，binary AppImage hash | **可半自动**：release 出现后用 nix-update（必要时指定 URL/文件）或 nurl/`nix store prefetch-file` 更新版本与 hash；必须构建/运行审阅 Electron、动态库和桌面集成 | 版本/hash 机械变更可自动提 PR；构建与兼容性人工批准 |
| Rime 覆盖同一 LTS asset | `pkgs/rime-wanxiang-grammar/default.nix`：固定 URL `.../releases/download/LTS/wanxiang-lts-zh-hans.gram`，无稳定版本号 | **必须人工触发**：同一 mutable tag 可能被覆盖，发现 hash 变化不代表语义版本；只在确认上游 LTS 内容/许可证后更新 hash | 不做“latest”自动升级；人工记录发布日期/上游变更，重新预取并审阅 |
| Windows 字体固定 commits | `pkgs/ttf-ms-win10/default.nix`：两个 GitHub repos，各自 immutable commit + hash，版本说明为 `unstable-2021-02-10`，且标注 unfree | **人工、低频**：只有字体缺失/文档兼容性需求或上游可信新 commit 才更新；两个 source 必须成对检查，关注许可证和字体内容 | 不跟随 branch/tag；可用 nurl 生成新 fetcher/hash，但不能替代许可证/视觉回归审阅 |
| 破坏性安装引导镜像 | `flake.nix` `kexec-installer`：`nixos-images` 的 `nixos-26.05` noninteractive x86_64 tar.gz，供 just install 的 `nixos-anywhere --kexec` 使用；justfile 注释说明内核/mdraid 兼容风险 | **人工、强门槛**：镜像升级可能改变 kexec 内核、存储探测和目标机可启动性；先在可抛弃目标/维护窗口验证，再改 URL/hash | 禁止无审阅自动合并；即使 Renovate/nvfetcher 提示新 tag，也只能提案 |

截至 2026-08-06 的上游状态：

- Orca 最新正式版是 [`v1.4.171`](https://github.com/stablyai/orca/releases/tag/v1.4.171)，本仓仍是 `1.4.170`，已经出现一个适合 nix-update 处理的机械更新。
- Rime LTS 的简体 asset 于 2026-08-05 重新发布；GitHub API 给出的 digest 转成 SRI 后正是本仓 `sha256-BRpVq7OCT+EDp68QuKyWtatOlwZ6HAzxyWiEHqKhw5E=`，当前已同步。
- 两个字体仓库的最新 commit 分别仍是本仓固定的 [`417eb232`](https://github.com/streetsamurai00mi/ttf-ms-win10/commit/417eb232e8d037964971ae2690560a7b12e5f0d4) 和 [`f5d2ef2c`](https://github.com/chillcicada/ttf-ms-win10-sc-sup/commit/f5d2ef2c84e8979b322563a53ea3adb5ab995176)，无需更新。
- `nixos-images` 最新正式 release 仍是 [`nixos-26.05`](https://github.com/nix-community/nixos-images/releases/tag/nixos-26.05)，kexec pin 当前没有落后。

“可自动”仅表示能生成候选版本/hash，不表示可安全部署。固定 output derivation 的 hash 保证内容可复现；mutable tag 的更新是内容漂移检测，不是可靠版本语义。

## 4. 方案比较（复杂度由低到高；风险为合并/运行破坏风险由低到高）

| 方案 | 复杂度 | 自动化 | 可复现性 | 破坏风险 | 适配本仓判断 |
|---|---:|---:|---:|---:|---|
| A. 原生、按类别手动：`nix flake update <input>` + nix-update/nurl/预取 + 人工审阅 | 低 | 中 | 高（保留 hash/pin） | 低 | **推荐**；无需新文件/依赖，最符合三小包现状 |
| B. Renovate Nix manager 只管 `flake.lock`，包更新仍手动 | 中 | 高（仅 inputs） | 高 | 中 | 可选；官方仍标 beta/默认关闭，适合先自动提 flake PR，不覆盖普通 package source |
| C. 给包添加 `passthru.updateScript`，由 nix-update/nixpkgs runner 调度 | 中 | 中—高 | 高 | 中 | Orca 可考虑；Rime mutable LTS、镜像和字体不应套通用脚本 |
| D. nvfetcher 管理全部普通包，或把包变成 NUR/flake inputs | 高 | 高（机械 source） | 高 | 中—高 | 不推荐：生成层/第三方聚合复杂度超过收益；NUR 也不解决本地维护与审批 |

排序说明：A < B/C < D 为实施复杂度；自动化则 B/D > C > A；可复现性只要最终提交 immutable hash 都高，mutable LTS 例外；破坏风险取决于资源类别，镜像最高，非工具本身能消除。

## 5. 最小推荐接口与触发条件

### 接口

1. **Flake inputs**：继续使用现有 `just up <input>`；`just update` 仅在明确要全量刷新时使用。Renovate 若启用，只匹配/维护 `flake.nix` + `flake.lock`，不要宣称包源已覆盖。
2. **可更新本地包**：把 Orca 暴露为 `packages.x86_64-linux.orca-ide`，获得统一的构建和更新 seam；然后用 `nix-update orca-ide --flake --url https://github.com/stablyai/orca --build --format` 生成并验证候选 diff。暂不增加 `passthru.updateScript`，重复手工调用确实成为负担后再加。
3. **人工包源**：Rime、字体和 kexec 保持现有 `fetchurl/fetchFromGitHub { url/rev; hash; }`；版本、URL/rev、hash、变更理由同一提交，kexec 另附目标机安装和重启验证。

### 触发条件

- flake input：上游安全修复、需要新模块/API、或维护窗口；按 input 更新而非默认全量。
- Orca：GitHub 正式 release 且需要功能/修复；先候选更新，再检查 AppImage 启动、Wayland/桌面项和运行库。
- Rime：明确确认 LTS asset 被上游重新发布且内容应接受；只改 hash/必要元数据，不把 tag 当版本号。
- 字体：确有字体缺失/排版回归或可信来源新 commit；重新检查 unfree 许可与两个仓库内容。
- kexec：nixos-anywhere/NixOS 镜像发布并有内核、mdraid 或安全修复需求；先单独安装演练，后改 pin。

## 6. 当前仓库下一步（最小改动）

本任务范围内**不修改任何 Nix 配置、justfile 或命令**；报告即唯一新增文件。后续真正变更时，最小顺序是：

1. 保持现有 `just update`/`just up`，其文档已经准确写明只处理 flake inputs。
2. Orca 当前已从 `1.4.170` 落后到 `1.4.171`；下一次实施时先将它暴露为 flake package output，再用 nix-update 更新和构建。不要先写自定义 updater。
3. Rime、字体、kexec 继续人工维护；不将 `pkgs` 变成 flake inputs/NUR。
4. 若希望自动提 flake PR，再单独启用 Renovate Nix manager，并把 `just check` 和人工审批作为合并条件。

## 关键一方来源

- Nix：[`nix flake update` 官方手册](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-update)
- nix-update：[`Mic92/nix-update` README](https://raw.githubusercontent.com/Mic92/nix-update/main/README.md)
- Nixpkgs updater runner：[`maintainers/scripts/update.nix`](https://github.com/NixOS/nixpkgs/blob/master/maintainers/scripts/update.nix)
- nurl：[`nix-community/nurl` README](https://raw.githubusercontent.com/nix-community/nurl/main/README.md)
- nvfetcher：[`berberman/nvfetcher` README](https://raw.githubusercontent.com/berberman/nvfetcher/master/README.md)
- Renovate：[`Nix manager` 官方文档](https://docs.renovatebot.com/modules/manager/nix/)
- NUR：[`nix-community/NUR` README](https://raw.githubusercontent.com/nix-community/NUR/master/README.md)
