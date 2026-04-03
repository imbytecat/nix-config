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
├── hosts/
│   ├── wsl/default.nix        # WSL：用户、WSL 设置
│   └── bare/default.nix       # 裸机：引导、网络、硬件
├── modules/
│   ├── base.nix               # 基础包（现代 CLI 工具）
│   ├── dev.nix                # 开发工具链 + LSP
│   ├── docker.nix             # Docker
│   ├── locale.nix             # 区域 / 语言
│   └── shell.nix              # Zsh 系统级启用
├── home/
│   ├── default.nix            # Home Manager 入口
│   ├── shell.nix              # Zsh + 终端增强工具
│   └── git.nix                # Git + Delta
└── scripts/
    └── install.sh             # 一键安装脚本
```

**配置层级**：`hosts/*`（主机特定） → `modules/*`（共享系统） → `home/*`（用户级）

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

编辑 `modules/base.nix` 或 `modules/dev.nix`，在 `environment.systemPackages` 中添加：

```nix
environment.systemPackages = with pkgs; [
  your-package  # ← 添加
];
```

> 查包名：`nix search nixpkgs <关键词>`

### 添加 Shell 别名

编辑 `home/shell.nix` 中的 `shellAliases`。
