# Arch Linux 配置仓库

使用 dcli 声明式管理 Arch Linux 配置（当前默认主机为 wsl，可扩展到其他主机）。

## 快速开始

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/install.sh | bash
```

安装完成后：

```bash
cd ~/.config/arch-config
dcli sync
```

## 配置说明

- `hosts/wsl.yaml` - WSL 配置
- `modules/` - 模块化包管理
- `files/` - 配置文件（自动同步）

## 更新配置

```bash
cd ~/.config/arch-config
git pull
dcli sync
```
