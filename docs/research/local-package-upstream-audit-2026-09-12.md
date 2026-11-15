# 本地包上游审计（2026-09-12）

## 方法与基线

- 审计对象：本仓 [`flake.nix`](../../flake.nix)、[`overlays/default.nix`](../../overlays/default.nix)、原 `pkgs/orca-ide`、原 `pkgs/rime-wanxiang-grammar`、`pkgs/ttf-ms-win10`，以及既有研究记录与实际调用点。
- 实际配置与 NixOS Package Search 的 `nixos-unstable` 数据都落在 nixpkgs [`8ce4ef6cb6f8`](https://github.com/NixOS/nixpkgs/commit/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe)（2026-09-10 02:20 UTC）；另以审计时 nixpkgs `master` [`357a2d91de6a`](https://github.com/NixOS/nixpkgs/commit/357a2d91de6a33ea893b200f480e5f9db1b0a7f5)（2026-09-12 01:16 UTC）交叉确认当前源码。
- “官方可用”同时检查包定义、NixOS Package Search 索引和 nixpkgs 默认安全求值规则；Search 能列出元数据，不代表默认用户求值会允许 insecure 依赖。
- Orca 迁移后执行了锁定包、桌面 `system.path` 构建与进程启动 smoke；未运行项目测试套件。

分类含义：**立即移除**＝已有等价替代且无需保留；**保留**＝当前没有合格替代；**有条件**＝满足列出的功能、许可或上游门槛后再移除/保留。

## 结论

| 本仓对象 | 官方 nixpkgs / 已锁输入 | 当前上游 | 建议 | 精确门槛 |
|---|---|---|---|---|
| Orca IDE | nixpkgs 的 `orca` 是 GNOME 屏幕阅读器 50.2；已锁 `llm-agents` 提供 stablyai Orca IDE 1.4.200 | stablyai Orca IDE 1.4.200 | **已移除本地包** | 桌面模块直接消费 input package，并删除与 GNOME Orca 冲突的同名 CLI 链接 |
| 原 `nixpkgs-pnpm-pin` / `cherry-studio` | 主 nixpkgs 仍为 1.9.11，与本地 pin 相同；默认安全求值会被 pnpm 10.29.2 与 Electron 40.10.5 阻断 | Cherry Studio 2.0.14 | **已移除** | 2026-11-15 不再使用 Cherry Studio，pin 与两端安装一并删除 |
| 原 `pkgs/rime-wanxiang-grammar` | nixpkgs 的 `rime-wanxiang` 方案不含可变的 LTS `.gram` | LTS 简体模型持续覆盖发布 | **已移除本地包** | 2026-11-14 输入法改用 WowType flake input，不再需要该模型 |
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

### 移除结果

2026-11-15 起不再使用 Cherry Studio。本仓已删除 `nixpkgs-pnpm-pin` input、overlay 中的 `cherry-studio`、Linux 包与 Darwin Homebrew cask；原 pin 的保留理由与退出门槛随之失效。

## 3. Rime 万象 LTS 语法模型

### 迁移结果

2026-11-14 起 `awesome-pc` 输入法从 fcitx5-rime + 万象改为 [WowType](https://github.com/Gloridust/WowType) flake input（[`modules/desktop/nixos.nix`](../../modules/desktop/nixos.nix)）。本仓已删除 `pkgs/rime-wanxiang-grammar`、对应 overlay、`just update` 中的哈希刷新脚本及其单测。WowType 的词库与语言模型由上游 `nix/package.nix` 按版本化发布资产固定 URL/hash，随 `nix flake update` 一并更新。

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
- 该 revision 的 [`packages/` 清单](https://github.com/numtide/llm-agents.nix/tree/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/packages)与[生成目录](https://github.com/numtide/llm-agents.nix/blob/95f48ce58bfb55a1a4d4d1ccdc4801b37cbb88c9/README.md#orca)没有 Windows 字体 attr。

因此 `llm-agents` 已接管 Orca，不改变字体的保留结论。
