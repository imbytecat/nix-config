# Arch Linux 配置仓库

使用 [decman](https://github.com/kiviktnm/decman) 声明式管理 Arch Linux 系统配置。
当前默认面向 WSL 环境；裸机使用请按需修改 `source.py`。

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
```

### B. 普通 Arch 安装（已存在普通用户）

跳过 WSL 初始化，直接执行：

```bash
curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash
```

## 更新配置

```bash
cd ~/.config/arch-config && git pull && sudo decman
```

## 仓库结构

```
.
├── source.py         # decman 主配置（包、系统文件、dotfiles）
├── files/            # 系统配置文件源
│   └── etc/
│       ├── pacman.d/mirrorlist
│       └── sudoers.d/10-wheel
├── dotfiles/         # 用户配置文件源
│   └── .zshrc
└── scripts/
    ├── install.sh    # 安装脚本（bootstrap → decman）
    └── wsl-init.sh   # WSL 首次初始化（创建用户）
```

## 配置说明

- `source.py` — 所有声明集中在一个文件：pacman 包、AUR 包、系统文件、dotfiles
- `files/` — 需要部署到 `/etc/` 的系统配置文件，目录结构对应目标路径
- `dotfiles/` — 需要部署到用户目录的配置文件
- `scripts/` — 一次性引导脚本，安装完成后由 `sudo decman` 接管日常管理
