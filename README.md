# Arch Linux 配置仓库

使用 dcli 声明式管理 Arch Linux 配置。
当前默认主机为 `wsl`；非 WSL 环境请先新增/切换 host，再执行同步。

## 使用方式

### A. Arch on WSL 首次启动（默认 root 登录）

1. 初始化普通用户：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/wsl-init.sh | bash -s -- <用户名>
```

2. 在 PowerShell 中重启 WSL：

```powershell
wsl --terminate archlinux
```

3. 重新进入 Arch WSL 后，以普通用户执行：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash
dcli sync
```

### B. 普通 Arch 安装（已存在普通用户）

跳过 WSL 初始化，直接执行：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash
dcli sync
```

> 注意：当前 `config.yaml` 的 `active_host` 是 `wsl`。非 WSL 环境请先新增对应 `hosts/*.yaml` 并切换 `active_host`。

## 配置说明

- `hosts/` - 主机配置
- `modules/` - 模块化包管理
- `files/` - 配置文件（自动同步）

## 更新配置

```bash
cd ~/.config/arch-config && git pull
dcli sync
```
