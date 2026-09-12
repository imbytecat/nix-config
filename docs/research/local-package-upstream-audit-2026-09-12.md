# 本地包上游审计（2026-09-12）

## 方法与基线

- 审计对象：本仓 [`flake.nix`](../../flake.nix)、[`overlays/default.nix`](../../overlays/default.nix)、原 `pkgs/orca-ide`、`pkgs/rime-wanxiang-grammar`、`pkgs/ttf-ms-win10`，以及既有研究记录与实际调用点。
- 实际配置与 NixOS Package Search 的 `nixos-unstable` 数据都落在 nixpkgs [`8ce4ef6cb6f8`](https://github.com/NixOS/nixpkgs/commit/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe)（2026-09-10 02:20 UTC）；另以审计时 nixpkgs `master` [`357a2d91de6a`](https://github.com/NixOS/nixpkgs/commit/357a2d91de6a33ea893b200f480e5f9db1b0a7f5)（2026-09-12 01:16 UTC）交叉确认当前源码。
- “官方可用”同时检查包定义、NixOS Package Search 索引和 nixpkgs 默认安全求值规则；Search 能列出元数据，不代表默认用户求值会允许 insecure 依赖。
- Orca 迁移后执行了锁定包、桌面 `system.path` 构建与进程启动 smoke；未运行项目测试套件。

分类含义：**立即移除**＝已有等价替代且无需保留；**保留**＝当前没有合格替代；**有条件**＝满足列出的功能、许可或上游门槛后再移除/保留。

## 结论

| 本仓对象 | 官方 nixpkgs / 已锁输入 | 当前上游 | 建议 | 精确门槛 |
|---|---|---|---|---|
| Orca IDE | nixpkgs 的 `orca` 是 GNOME 屏幕阅读器 50.2；已锁 `llm-agents` 提供 stablyai Orca IDE 1.4.200 | stablyai Orca IDE 1.4.200 | **已移除本地包** | 桌面模块直接消费 input package，并删除与 GNOME Orca 冲突的同名 CLI 链接 |
| `nixpkgs-pnpm-pin` / `cherry-studio` | 主 nixpkgs 仍为 1.9.11，与本地 pin 相同；默认安全求值会被 pnpm 10.29.2 与 Electron 40.10.5 阻断 | Cherry Studio 2.0.14 | **保留** | nixpkgs 包本身更新到无 insecure Electron/pnpm、默认求值不再拒绝，并确认缓存可接受；不能只看应用版本号 |
| `pkgs/rime-wanxiang-grammar` | 有 `rime-wanxiang` 17.9.3 方案，但官方明确不含可变的 LTS `.gram` | 方案 17.9.9；LTS 简体模型于 2026-09-12 再次覆盖发布 | **保留** | 上游提供不可变、带版本的模型资产，且 nixpkgs 出现包含同等简体模型的可复现包 |
| `pkgs/ttf-ms-win10` | 仅有 `corefonts`、`vista-fonts`、`vista-fonts-chs` 等部分集合；没有完整 Windows 10 等价包 | 两个本地来源仓均已归档 | **有条件保留** | 只有确认该来源与跨设备使用权、且确需 WPS/Office 精确字体名称和度量时保留；否则立即移除或接受部分/自由字体替代 |

## 1. stablyai Orca IDE

### 迁移结果

本仓已删除原 `pkgs/orca-ide` AppImage 包及 overlay，改由 [`modules/desktop/nixos.nix`](../../modules/desktop/nixos.nix) 直接消费：

```nix
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.orca
```

Plasma 同时安装 nixpkgs 的 GNOME Orca 屏幕阅读器，二者都提供 `bin/orca`。桌面模块用 `symlinkJoin` 只从 llm-agents 包暴露 `orca-ide` GUI，保留 GNOME Orca 的 `orca`，避免 system profile 文件冲突。`packages.x86_64-linux.orca` 仅重导出未修改的 llm-agents derivation，供 CI 与手工定点构建。

必须区分两个同名项目：

- nixpkgs [`orca`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/or/orca/package.nix) 的主页是 `orca.gnome.org`、描述为 “Screen reader”、版本 **50.2**。
- stablyai 上游最新正式版是 [`v1.4.200`](https://github.com/stablyai/orca/releases/tag/v1.4.200)，本仓锁定的 llm-agents package 已同步。

### 验证

1. `nix build .#orca` 可取得 llm-agents 的 **1.4.200** 包；
2. `awesome-pc.config.system.path` 构建成功，没有 `bin/orca` 文件冲突；
3. system path 中 `orca` 指向 GNOME Orca 50.2，`orca-ide` 指向 llm-agents Orca IDE 1.4.200；
4. `orca-ide --version` 输出 `1.4.200`；
5. 独立临时 profile 下启动 Electron 进程并开放 CDP 成功。本次未继续做 Wayland 输入法与业务交互自动化。

更新责任随之简化：`just update` 只刷新 flake inputs；依赖工作流构建 `.#orca` 后运行仓库检查，不再调用 nix-update 或维护本地 AppImage hash。

## 2. Cherry Studio 与 `nixpkgs-pnpm-pin`

### 版本、求值与安全状态

本仓 [`flake.nix`](../../flake.nix) 固定 nixpkgs [`4c5fd5ac81ed`](https://github.com/NixOS/nixpkgs/commit/4c5fd5ac81ed3f63654e295d49552ca1dbc65447)（2026-06-21），overlay 用该 revision 的 `cherry-studio` 覆盖主包集。Linux 安装此包；Darwin 走独立 Homebrew cask，不受该 pin 的移除与否影响。

主 nixpkgs **没有比 pin 更新**：

- [NixOS Package Search](https://search.nixos.org/packages?channel=unstable&query=cherry-studio) 在实际基线 `8ce4ef6c` 显示 **1.9.11**；审计时 [`master` 包定义](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/ch/cherry-studio/package.nix) 仍是 **1.9.11**，依赖 `electron_40` 与 `pnpm_10_29_2`。
- 当前 [`pnpm` 定义](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/development/tools/pnpm/default.nix) 为 10.29.2 列出 **12 个 CVE**。
- `electron_40` 在 [`all-packages.nix`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/top-level/all-packages.nix#L4743-L4804) 指向 binary 包；[`binary/info.json`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/development/tools/electron/binary/info.json) 给出版本 **40.10.5**，而 [`binary/generic.nix`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/development/tools/electron/binary/generic.nix#L43-L51) 将所有 `< 42.0.0` 版本标为 EOL。Electron 官方也只支持[最新三个稳定大版本](https://www.electronjs.org/docs/latest/tutorial/electron-timelines)。
- nixpkgs [`check-meta.nix`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/stdenv/generic/check-meta.nix#L202-L217) 默认不允许 `knownVulnerabilities` 非空的 derivation，并在[错误处理](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/stdenv/generic/check-meta.nix#L620-L681)中抛出 `Refusing to evaluate package ... because it is marked as insecure`。因此 pnpm 与 Electron 任一项都足以阻断标准求值；Search 中出现包名不代表可直接安装。

旧 pin 的 [`cherry-studio`](https://github.com/NixOS/nixpkgs/blob/4c5fd5ac81ed3f63654e295d49552ca1dbc65447/pkgs/by-name/ch/cherry-studio/package.nix) 同样使用 pnpm **10.29.2** 和 Electron **40.10.3**。该 revision 尚未给 pnpm 写入后来的 CVE 列表，Electron EOL 门槛也仍是 `< 40`，所以它保留了可求值性和旧缓存；这是**绕过后来元数据，不是安全修复**。

上游最新为 [`v2.0.14`](https://github.com/CherryHQ/cherry-studio/releases/tag/v2.0.14)（2026-09-09）。其官方 `package.json` 使用 Electron **41.8.0** 与 electron-builder **26.15.6**（[源码](https://github.com/CherryHQ/cherry-studio/blob/v2.0.14/package.json#L370-L371)），并用 pnpm **11.8.0**（[源码](https://github.com/CherryHQ/cherry-studio/blob/v2.0.14/package.json#L509)）；pnpm 已离开 10.29.2，但 Electron 41 仍低于 nixpkgs 当前 `< 42` EOL 门槛，故不能仅凭“上游已到 2.x”判断安全或可求值。

### 建议与退出门槛

**保留 pin，禁止用 `permittedInsecurePackages` 代替。** 精确退出条件：

1. 主 nixpkgs 的 `cherry-studio` 包定义已更新，而非只有 Cherry 上游发布新版；
2. 它实际选用的 Electron、pnpm 及被强制求值的依赖均无 `knownVulnerabilities`，标准 `drvPath` 求值不再出现 `Refusing to evaluate`，且未设置 `NIXPKGS_ALLOW_INSECURE`/allowlist；
3. dry-run 显示二进制缓存命中和本地构建量可接受；
4. 满足后同时删除 overlay 的 `inherit ... cherry-studio`、`flake.nix` 的 `nixpkgs-pnpm-pin` input 及对应 lock 节点，让 Linux 直接使用主 nixpkgs。Darwin Homebrew cask 保持独立。

## 3. Rime 万象 LTS 语法模型

### 现状与证据

本仓 [`pkgs/rime-wanxiang-grammar/default.nix`](../../pkgs/rime-wanxiang-grammar/default.nix) 只安装 `wanxiang-lts-zh-hans.gram`，与 nixpkgs 的 `rime-wanxiang` 方案一起传给 `fcitx5-rime`。

- nixpkgs 已有 [`rime-wanxiang`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/ri/rime-wanxiang/package.nix) **17.9.3**，[Package Search](https://search.nixos.org/packages?channel=unstable&query=rime-wanxiang) 也只列出该方案包；它的 `longDescription` 明确说 LTS release 会覆盖旧资产，不能进入要求可复现的 nixpkgs，用户必须自行下载 `.gram`。
- 上游方案最新正式版是 [`v17.9.9`](https://github.com/amzxyz/rime-wanxiang/releases/tag/v17.9.9)（2026-09-08），并仍将该模型列为所有方案的必装组件。
- 上游 [issue #22](https://github.com/amzxyz/RIME-LMDG/issues/22) 明确确认继续覆盖同一 LTS release；这不是稳定版本语义。
- [`LTS` release](https://github.com/amzxyz/RIME-LMDG/releases/tag/LTS) 的简体资产于 2026-09-12 00:34 UTC 更新，GitHub digest `sha256:9f80530f…` 转为 SRI 后正是本仓 `sha256-n4BTD0cAM8+21LRLuGG1QPZBAEJvkt0PhxQIg2MqPZM=`，当前内容已同步。

### 建议与退出门槛

**保留。** 只有同时满足以下条件才移除：上游停止覆盖、发布不可变且带版本的简体模型资产；nixpkgs 随后提供该模型或把它纳入官方 `rime-wanxiang`；新包与当前方案组合可正常部署。届时删除 `rime-wanxiang-grammar` overlay/本地定义，并从 `rimeDataPkgs` 移除本地 attr 或替换为官方 attr。

## 4. Windows 10 字体

### 现状、等价性与许可

本仓 [`pkgs/ttf-ms-win10/default.nix`](../../pkgs/ttf-ms-win10/default.nix) 合并两个固定提交：

- [`streetsamurai00mi/ttf-ms-win10@417eb232`](https://github.com/streetsamurai00mi/ttf-ms-win10/tree/417eb232e8d037964971ae2690560a7b12e5f0d4)：完整度较高的 Windows 10 字体快照，最后提交为 2021-02-09，仓库现已归档；
- [`chillcicada/ttf-ms-win10-sc-sup@f5d2ef2c`](https://github.com/chillcicada/ttf-ms-win10-sc-sup/tree/f5d2ef2c84e8979b322563a53ea3adb5ab995176)：补入 DengXian、FangSong、KaiTi、SimHei，最后提交为 2025-06-03，仓库现已归档。

nixpkgs 没有完整等价包。[Package Search 的 Microsoft fonts 结果](https://search.nixos.org/packages?channel=unstable&query=microsoft%20fonts)只有部分集合：

- [`corefonts`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/co/corefonts/package.nix)：旧 Web core fonts；
- [`vista-fonts`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/vi/vista-fonts/package.nix)：Calibri、Cambria、Candara、Consolas、Constantia、Corbel；
- [`vista-fonts-chs`](https://github.com/NixOS/nixpkgs/blob/357a2d91de6a33ea893b200f480e5f9db1b0a7f5/pkgs/by-name/vi/vista-fonts-chs/package.nix)：仅 Microsoft YaHei。

这些包不能覆盖本仓为 WPS/Office 版式保真的完整具名字体，尤其不能补齐 SimHei/KaiTi/FangSong/DengXian。Microsoft 的[官方 Windows 10 字体列表](https://learn.microsoft.com/en-us/typography/fonts/windows_10_font_list)确认这些字族属于 Windows 字体/FOD；其[字体再分发 FAQ](https://learn.microsoft.com/en-us/typography/fonts/font-faq)明确写明，除文档嵌入等例外外，通常不得再分发 Windows 字体，也不得复制到其他计算机或服务器。拥有 Windows 本身不应被自动视为已经授权从第三方仓库下载并安装到 Linux；本报告不作法律结论。

### 建议与退出门槛

**有条件保留：**仅在使用者已确认该确切来源和跨设备安装获得授权，并且 WPS/Office 文档确需相同字体名称、字宽和分页时保留。

否则应立即从 `fonts.packages` 删除 `ttf-ms-win10`，再删除 overlay 与本地定义：

- 若只需常见西文字体，可接受 `corefonts`/`vista-fonts`；
- 若只需微软雅黑，可接受 `vista-fonts-chs`；
- 若不要求像素/分页一致，应优先继续使用本仓已有 Noto、Sarasa、LXGW 等自由字体。

未来完整移除 gate：不再需要精确 WPS/Office 版式，或 nixpkgs 出现来源与许可可接受、并覆盖全部实际所需具名字体的官方包。当前不存在这样的等价包。

## 5. 已锁 `numtide/llm-agents.nix` 交叉审计

本仓 `llm-agents` 锁在 [`95f48ce58bfb`](https://github.com/numtide/llm-agents.nix/commit/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9)（2026-09-11 23:55 UTC）。该 flake 的 [`flake.nix`](https://github.com/numtide/llm-agents.nix/blob/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/flake.nix) 把 `packages/<name>/` 自动暴露为 `packages.<system>.<name>`。

- [`packages/orca/package.nix`](https://github.com/numtide/llm-agents.nix/blob/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/packages/orca/package.nix) 明确打包 `stablyai/orca` 官方 deb，attr/pname 为 `orca`、`mainProgram = "orca-ide"`，支持 x86_64-linux 与 aarch64-linux，同时提供 `orca-ide` GUI 和 `orca` CLI；[`hashes.json`](https://github.com/numtide/llm-agents.nix/blob/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/packages/orca/hashes.json) 为 **1.4.200**。本仓已迁移到该 package。
- 定点验证确认该锁定 attr 命中 `cache.numtide.com`，`orca --version` 与 `orca-ide --version` 均成功；桌面 system path 额外裁掉同名 `orca` CLI，保留 Plasma 的 GNOME Orca。
- 该 revision 的 [`packages/` 清单](https://github.com/numtide/llm-agents.nix/tree/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/packages)与[生成目录](https://github.com/numtide/llm-agents.nix/blob/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/README.md#orca)没有 Cherry Studio、Rime grammar 或 Windows 字体 attr。目录中其他 AI 桌面/代理工具属于不同产品，不能作为 Cherry Studio 配置与数据的原位替代。

因此 `llm-agents` 已接管 Orca，不改变 Cherry pin、Rime 模型或字体的保留结论。
