# NixOS 声明式系统配置

使用 [NixOS](https://nixos.org/) + [Home Manager](https://github.com/nix-community/home-manager) + [Flakes](https://nix.dev/concepts/flakes) 声明式管理系统配置。

支持 **WSL** 和**裸机**两种部署方式，共享同一套模块。

## 快速开始

### WSL

1. 安装 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL/releases)：

```powershell
wsl --import NixOS C:\wsl\nixos nixos-wsl.tar.gz
wsl -d NixOS
```

2. 运行安装脚本：

```bash
bash <(curl -fsSL https://git.furtherverse.com/imbytecat/nix-config/raw/branch/main/scripts/install.sh)
```

3. 重新登录，配置 Git 身份：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

### 裸机

1. 安装 NixOS 基础系统
2. 运行安装脚本（传入 `bare` 参数）：

```bash
bash <(curl -fsSL https://git.furtherverse.com/imbytecat/nix-config/raw/branch/main/scripts/install.sh) bare
```

3. 生成硬件配置并重新应用：

```bash
cd ~/.config/nix-config
sudo nixos-generate-config --show-hardware-config > hosts/bare/hardware-configuration.nix
# 取消 hosts/bare/default.nix 中 imports 的注释
sudo nixos-rebuild switch --flake .#bare
```

## 仓库结构

```
├── flake.nix                  # 入口：输入源 + 输出配置
├── flake.lock                 # 依赖锁定文件（需手动生成）
├── hosts/
│   ├── wsl/default.nix        # WSL：用户、WSL 设置
│   └── bare/default.nix       # 裸机：引导、网络、硬件
├── modules/
│   ├── nixos/                 # NixOS 专用模块
│   │   ├── base.nix           # 基础包
│   │   ├── docker.nix         # Docker 配置
│   │   ├── locale.nix         # 区域 / 语言
│   │   └── default.nix        # 入口
│   ├── darwin/                # macOS 专用模块（预留）
│   └── shared/                # 共享模块
│       ├── nix.nix            # Nix 设置
│       └── default.nix        # 入口
├── home/                      # Home Manager 配置
│   ├── default.nix            # 入口
│   ├── theme.nix              # Catppuccin 主题
│   ├── dev/                   # 开发工具
│   │   ├── neovim.nix
│   │   ├── languages.nix      # 语言运行时、LSP
│   │   ├── git.nix
│   │   └── default.nix
│   └── shell/                 # Shell 配置
│       ├── zsh.nix
│       ├── tmux.nix
│       ├── starship.nix
│       ├── tools.nix          # fzf, atuin, zoxide 等
│       └── default.nix
├── lib/                       # 辅助函数
│   └── default.nix
├── overlays/                  # 自定义包覆盖
│   └── default.nix
├── pkgs/                      # 自定义包（预留）
│   └── default.nix
└── scripts/
    └── install.sh             # 一键安装脚本
```

**配置层级**：`hosts/*`（主机特定） → `modules/*`（共享系统） → `home/*`（用户级）

## 首次设置（重要）

### 生成 flake.lock

首次克隆仓库后，必须生成锁定文件以确保依赖版本一致：

```bash
cd ~/.config/nix-config
nix flake lock
git add flake.lock
git commit -m "Add flake.lock"
```

**为什么需要？** `flake.lock` 锁定所有输入（nixpkgs、home-manager 等）的确切版本，确保不同机器构建结果一致。

## 日常使用

```bash
cd ~/.config/nix-config

# 更新配置
git pull && sudo nixos-rebuild switch --flake .#wsl

# 更新所有包版本
nix flake update && sudo nixos-rebuild switch --flake .#wsl

# 回滚到上一版本
sudo nixos-rebuild switch --rollback

# 清理旧 generation（释放磁盘）
sudo nix-collect-garbage -d
```

## 自定义

### 修改用户名

编辑 `hosts/wsl/default.nix`（或 `hosts/bare/default.nix`）顶部：

```nix
let
  username = "你的用户名";
```

### 添加包

编辑 `modules/nixos/base.nix` 或 `home/dev/languages.nix`，在对应 `packages` 列表中添加：

```nix
environment.systemPackages = with pkgs; [
  your-package  # ← 添加
];
```

> 查包名：`nix search nixpkgs <关键词>` 或查看 [NixOS 包搜索](https://search.nixos.org/packages)

### 添加 Shell 别名

编辑 `home/shell/zsh.nix` 中的 `shellAliases`。
