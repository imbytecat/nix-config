# Arch Linux WSL 初始化配置

使用 dcli 声明式管理 Arch Linux 配置。

## 快速开始

```bash
# 1. 克隆仓库
git clone https://git-ssh.furtherverse.com/imbytecat/archlinux-wsl-init.git
cd archlinux-wsl-init

# 2. 运行 bootstrap（安装 yay 和 dcli）
chmod +x bootstrap.sh
./bootstrap.sh

# 3. 检查配置（可选）
cat ~/.config/arch-config/hosts/wsl.yaml

# 4. 应用配置
dcli sync
```

## 配置说明

- `arch-config/hosts/wsl.yaml` - WSL 配置
- `arch-config/modules/` - 模块化包管理
- `arch-config/files/` - 配置文件（自动同步）

## 更新配置

```bash
# 拉取最新配置
cd ~/archlinux-wsl-init  # 或你的 clone 目录
git pull

# 应用更新
dcli sync

# 更新系统包
dcli update
```
