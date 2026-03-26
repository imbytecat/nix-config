# Arch Linux 配置仓库

使用 [decman](https://github.com/kiviktnm/decman) 声明式管理 Arch Linux 系统配置。
默认面向 WSL 环境；裸机使用请按需修改 `source.py`。

## 使用

### WSL 首次启动（默认 root 登录）

1. 初始化普通用户：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/wsl-init.sh | bash -s -- <用户名>
```

2. 在 PowerShell 中设置默认用户并重启：

```powershell
wsl --manage archlinux --set-default-user <用户名>
wsl --terminate archlinux
```

3. 重新进入 WSL，以普通用户执行：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash
```

### 非 WSL 环境

直接执行第 3 步。

## 更新配置

```bash
cd ~/.config/archlinux-config && git pull && sudo decman
```
