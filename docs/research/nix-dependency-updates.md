# Nix 依赖更新研究

> 范围：基于 Nix/Nixpkgs 官方文档与源码、工具官方仓库、Renovate 官方文档，并记录本仓当前自动化边界。

## 结论先行

- **没有一个原生命令能更新所有 Nix 依赖。** `nix flake update` 只刷新 `flake.lock`；普通 `.nix` 中的 `fetchurl`/`fetchFromGitHub` 仍需包级 updater。
- **本仓采用最小组合。** `just update` 顺序运行 `nix flake update` 与 nix-update，只机械维护 flake inputs 和 Orca。
- **Rime、字体和 kexec 保留人工门槛。** 它们只有上游状态提示，不进入自动修改或自动合并。
- **GitHub Actions 是编排层。** 每周更新后构建 Orca、运行 `just check`，成功则创建 PR 并自动 squash 合并；失败则保留 PR 和日志。

## 1. `nix flake update` 职责边界

Nix 官方手册把命令定义为 “update flake lock file”，并说明默认更新全部 inputs，也可传入 input 名称；相关 `nix flake lock` 只添加缺失输入、不会更新已有锁项，因此更安全（Nix 2.34.9 文档：[官方手册](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-update)）。

本仓 `flake.nix` 的 inputs 包括 nixpkgs、home-manager、nix-darwin、工具 flake 和非 flake GitHub 资源；`nix flake update` 只触碰 `flake.lock`，不会发现 `pkgs/orca-ide/default.nix` 的 GitHub release 或重算普通 `fetchurl` hash。

因此 `just update` 显式组合两层：先更新全部 flake inputs，再用 nix-update 更新 Orca；`just up input` 仍用于选择性更新单个 input。

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
| Orca GitHub release | `pkgs/orca-ide/default.nix`：`fetchurl` 指向 `stablyai/orca/releases/download/v${version}/orca-linux.AppImage`，binary AppImage hash | **自动候选**：nix-update 更新版本与 hash，`nix build .#orca-ide` 验证 AppImage 可打包 | 更新、构建和全量检查成功后自动合并 |
| Rime 覆盖同一 LTS asset | `pkgs/rime-wanxiang-grammar/default.nix`：固定 URL `.../releases/download/LTS/wanxiang-lts-zh-hans.gram`，无稳定版本号 | **必须人工触发**：同一 mutable tag 可能被覆盖，发现 hash 变化不代表语义版本；只在确认上游 LTS 内容/许可证后更新 hash | 不做“latest”自动升级；人工记录发布日期/上游变更，重新预取并审阅 |
| Windows 字体固定 commits | `pkgs/ttf-ms-win10/default.nix`：两个 GitHub repos，各自 immutable commit + hash，版本说明为 `unstable-2021-02-10`，且标注 unfree | **人工、低频**：只有字体缺失/文档兼容性需求或上游可信新 commit 才更新；两个 source 必须成对检查，关注许可证和字体内容 | 不跟随 branch/tag；可用 nurl 生成新 fetcher/hash，但不能替代许可证/视觉回归审阅 |
| 破坏性安装引导镜像 | `flake.nix` `kexec-installer`：`nixos-images` 的 `nixos-26.05` noninteractive x86_64 tar.gz，供 just install 的 `nixos-anywhere --kexec` 使用；justfile 注释说明内核/mdraid 兼容风险 | **人工、强门槛**：镜像升级可能改变 kexec 内核、存储探测和目标机可启动性；先在可抛弃目标/维护窗口验证，再改 URL/hash | 禁止无审阅自动合并；即使 Renovate/nvfetcher 提示新 tag，也只能提案 |

截至 2026-08-06 的上游状态：

- Orca 最新正式版是 [`v1.4.173`](https://github.com/stablyai/orca/releases/tag/v1.4.173)，本仓已由自动更新 PR 同步。
- Rime LTS 的简体 asset 于 2026-08-05 重新发布；GitHub API 给出的 digest 转成 SRI 后正是本仓 `sha256-BRpVq7OCT+EDp68QuKyWtatOlwZ6HAzxyWiEHqKhw5E=`，当前已同步。
- 两个字体仓库的最新 commit 分别仍是本仓固定的 [`417eb232`](https://github.com/streetsamurai00mi/ttf-ms-win10/commit/417eb232e8d037964971ae2690560a7b12e5f0d4) 和 [`f5d2ef2c`](https://github.com/chillcicada/ttf-ms-win10-sc-sup/commit/f5d2ef2c84e8979b322563a53ea3adb5ab995176)，无需更新。
- `nixos-images` 最新正式 release 仍是 [`nixos-26.05`](https://github.com/nix-community/nixos-images/releases/tag/nixos-26.05)，kexec pin 当前没有落后。

“可自动”表示能生成候选版本/hash并通过仓库检查，不等于可安全部署到正在运行的机器。固定 output derivation 的 hash 保证内容可复现；mutable tag 的更新是内容漂移检测，不是可靠版本语义。

## 4. 方案比较（复杂度由低到高；风险为合并/运行破坏风险由低到高）

| 方案 | 复杂度 | 自动化 | 可复现性 | 破坏风险 | 适配本仓判断 |
|---|---:|---:|---:|---:|---|
| A. 当前工作流：`nix flake update` + nix-update + 构建/检查 + 自动合并 | 低—中 | 高（安全子集） | 高（保留 hash/pin） | 中 | **采用中**；没有新更新框架，Rime/字体/kexec 仍隔离 |
| B. Renovate Nix manager 只管 `flake.lock`，包更新仍手动 | 中 | 高（仅 inputs） | 高 | 中 | 可选；官方仍标 beta/默认关闭，适合先自动提 flake PR，不覆盖普通 package source |
| C. 给包添加 `passthru.updateScript`，由 nix-update/nixpkgs runner 调度 | 中 | 中—高 | 高 | 中 | Orca 可考虑；Rime mutable LTS、镜像和字体不应套通用脚本 |
| D. nvfetcher 管理全部普通包，或把包变成 NUR/flake inputs | 高 | 高（机械 source） | 高 | 中—高 | 不推荐：生成层/第三方聚合复杂度超过收益；NUR 也不解决本地维护与审批 |

排序说明：A 只组合仓库已有命令；B/C 引入额外管理入口；D 增加生成层。可复现性只要最终提交 immutable hash 都高，mutable LTS 例外；破坏风险取决于资源类别，镜像最高，非工具本身能消除。

## 5. 最小推荐接口与触发条件

### 接口

1. **Flake inputs**：`just update` 全量刷新，`just up <input>` 选择性刷新；工作流提交 `flake.lock` 候选。
2. **可更新本地包**：Orca 暴露为 `packages.x86_64-linux.orca-ide`；`nix-update orca-ide --flake --system x86_64-linux --url https://github.com/stablyai/orca --use-github-releases` 更新版本与 hash，随后单独构建。
3. **人工包源**：Rime、字体和 kexec 保持现有 `fetchurl/fetchFromGitHub { url/rev; hash; }`；工作流只报告上游状态。

### 触发条件

- flake input：每周生成全量候选并执行仓库检查；需要单独控制时仍可 `just up <input>`。
- Orca：发现 GitHub 正式 release 后自动更新版本/hash并构建；运行时部署仍随正常 `switch` 流程。
- Rime：明确确认 LTS asset 被上游重新发布且内容应接受；只改 hash/必要元数据，不把 tag 当版本号。
- 字体：确有字体缺失/排版回归或可信来源新 commit；重新检查 unfree 许可与两个仓库内容。
- kexec：nixos-anywhere/NixOS 镜像发布并有内核、mdraid 或安全修复需求；先单独安装演练，后改 pin。

## 6. 当前仓库实现

1. `just update` 统一运行 flake input 更新与 Orca 的 nix-update。
2. `packages.x86_64-linux.orca-ide` 提供稳定的更新和构建入口；`src` 显式暴露给 nix-update 重算 fixed-output hash。
3. `.github/workflows/dependency-update.yml` 每周运行更新、`nix build .#orca-ide` 与 `just check`；成功自动 squash 合并，失败保留 PR。
4. `.github/dependabot.yml` 单独维护 GitHub Actions 版本。
5. Rime、字体和 kexec 不自动改；其中 mutable LTS 和安装镜像仍要求人工判断。

## 关键一方来源

- Nix：[`nix flake update` 官方手册](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-update)
- nix-update：[`Mic92/nix-update` README](https://raw.githubusercontent.com/Mic92/nix-update/main/README.md)
- Nixpkgs updater runner：[`maintainers/scripts/update.nix`](https://github.com/NixOS/nixpkgs/blob/master/maintainers/scripts/update.nix)
- nurl：[`nix-community/nurl` README](https://raw.githubusercontent.com/nix-community/nurl/main/README.md)
- nvfetcher：[`berberman/nvfetcher` README](https://raw.githubusercontent.com/berberman/nvfetcher/master/README.md)
- Renovate：[`Nix manager` 官方文档](https://docs.renovatebot.com/modules/manager/nix/)
- NUR：[`nix-community/NUR` README](https://raw.githubusercontent.com/nix-community/NUR/master/README.md)
