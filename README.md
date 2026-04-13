# Nix Config

使用 [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) + [Home Manager](https://github.com/nix-community/home-manager) + [Flakes](https://nix.dev/concepts/flakes) 声明式管理三台设备的系统配置。

## 设备

| 设备 | 平台 | Flake 目标 | 主机名 |
|------|------|-----------|--------|
| Mac Mini | aarch64-darwin | `mac-mini` | awesome-mac-mini |
| MacBook Air | aarch64-darwin | `macbook-air` | awesome-macbook-air |
| Windows PC (WSL) | x86_64-linux | `wsl` | awesome-wsl |

## 快速开始

### macOS (Mac Mini / MacBook Air)

1. 安装 [Lix](https://lix.systems/)（Nix 的社区分支，nix-darwin 官方推荐）：

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

2. 克隆仓库并首次构建：

```bash
git clone <repo-url> ~/nix-config
cd ~/nix-config
# 首次（nix-darwin 尚未安装）：
sudo nix run nix-darwin -- switch --flake .#mac-mini
# 之后日常重建：
sudo darwin-rebuild switch --flake .#mac-mini
```

### WSL (Windows PC)

1. 安装 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL/releases)：

```powershell
wsl --import NixOS C:\wsl\nixos nixos-wsl.tar.gz
wsl -d NixOS
```

2. 首次初始化（全新的 NixOS-WSL 没有 `git`，需要借助 `nix-shell` 临时引入）：

```bash
nix-shell -p git --run "git clone <repo-url> ~/nix-config"
cd ~/nix-config
sudo nixos-rebuild switch --flake .#wsl
```

> 首次 rebuild 完成后 `git`、`just` 等工具会由配置声明安装，此后可直接使用 `just rebuild` 重建。

## 仓库结构

```
├── flake.nix                  # 入口：输入源 + 输出配置
├── flake.lock                 # 依赖锁定文件
├── hosts/
│   ├── mac-mini/default.nix   # Mac Mini 特定配置
│   ├── macbook-air/default.nix# MacBook Air 特定配置
│   └── wsl/default.nix        # WSL 特定配置
├── modules/
│   ├── darwin/default.nix     # macOS 模块（Homebrew、系统偏好等）
│   ├── nixos/                 # NixOS 模块
│   │   ├── base.nix           # 基础包
│   │   ├── docker.nix         # Docker 配置
│   │   ├── locale.nix         # 区域 / 语言
│   │   └── default.nix        # 入口（用户、shell）
│   └── shared/                # 共享模块（Nix 设置）
├── home/                      # Home Manager 配置
│   ├── default.nix            # 入口 + 用户级包
│   ├── theme.nix              # Catppuccin 主题
│   ├── dev/                   # 开发工具
│   │   ├── neovim.nix
│   │   ├── languages.nix      # 语言运行时、LSP
│   │   └── git.nix
│   └── shell/                 # Shell 配置
│       ├── fish.nix           # Fish shell
│       ├── starship.nix       # Prompt
│       └── tools.nix          # fzf, atuin, zoxide 等
├── lib/default.nix            # 构建辅助函数
├── overlays/                  # 自定义包覆盖
└── pkgs/                      # 自定义包
```

**配置层级**：`hosts/*`（主机特定） → `modules/*`（平台模块） → `home/*`（用户级，跨平台共享）

## 日常使用

项目提供 [`justfile`](justfile)，首次 rebuild 后即可使用：

```bash
just rebuild <host>   # 重建系统（自动选择 darwin-rebuild / nixos-rebuild）
just update           # 更新所有 flake 输入
just up <input>       # 更新单个输入，如 just up nixpkgs
just check            # 检查配置是否能正常 evaluate
just clean            # 清理旧 generation 并回收空间
just rollback         # 回滚到上一个 generation（仅 NixOS）
just history          # 查看系统 profile 历史
just show             # 显示 flake 输出
```

Fish shell 中也定义了 abbreviation 可直接使用：

```bash
rebuild               # 自动选择 darwin-rebuild 或 nixos-rebuild
update                # nix flake update
```

> **注意**：`just clean` 仅清理用户级 generation。NixOS 上如需清理系统级旧 generation，需要 `sudo nix-collect-garbage -d`。

## Shell

使用 **Fish** 作为默认 shell，搭配：

- **Starship** — 跨平台 prompt
- **Atuin** — shell 历史搜索
- **Zoxide** — 智能 cd（`cd` = zoxide, `cdi` = 交互选择）
- **FZF** — 模糊搜索（Ctrl-R 历史, Ctrl-T 文件, Alt-C 目录）
- **Direnv** — 自动加载项目环境
- **Catppuccin Mocha** — 统一主题

### 自定义

- 添加 fish abbreviation: 编辑 `home/shell/fish.nix` 中的 `shellAbbrs`
- 添加包: 编辑 `home/default.nix` 或 `home/dev/languages.nix`
- 添加 Homebrew cask: 编辑 `modules/darwin/default.nix` 中的 `homebrew.casks`
- 查包名: `nix search nixpkgs <关键词>` 或 [search.nixos.org](https://search.nixos.org/packages)
