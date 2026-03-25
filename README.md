# Arch Linux WSL 初始化配置

使用 dcli 声明式管理 Arch Linux 配置。

## 快速开始

```bash
# 1. 克隆仓库
git clone git@git-ssh.furtherverse.com:imbytecat/archlinux-wsl-init.git
cd archlinux-wsl-init

# 2. 运行 bootstrap（仅首次）
chmod +x bootstrap.sh
./bootstrap.sh
```

## 配置说明

- `arch-config/hosts/wsl.yaml` - WSL 配置
- `arch-config/modules/` - 模块化包管理
- `arch-config/files/` - 配置文件（自动同步）

## 更新配置

```bash
# 修改配置后同步
dcli sync

# 更新系统
dcli update
```
