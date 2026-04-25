# Nix Config

nix-darwin + NixOS-WSL + Home Manager + Flakes 声明式管理三台设备的系统配置。

## 设备

| 设备 | 平台 | Flake 目标 | 主机名 |
|------|------|-----------|--------|
| Mac Mini | aarch64-darwin | `mac-mini` | awesome-mac-mini |
| MacBook Air | aarch64-darwin | `macbook-air` | awesome-macbook-air |
| Windows PC (WSL) | x86_64-linux | `wsl` | awesome-wsl |

## 快速开始

### macOS

1. 安装 [Lix](https://lix.systems/)：

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

2. 安装 [Homebrew](https://brew.sh/)（nix-darwin 不会自动安装）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. 克隆仓库并首次构建：

```bash
git clone <repo-url> ~/nix-config
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake .#macbook-air
```

之后日常重建：`just rebuild macbook-air`

### WSL

1. 启用 WSL 并更新内核：

```powershell
wsl --install --no-distribution
wsl --update
```

2. 安装 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL/releases)：

```powershell
wsl --import NixOS C:\wsl\nixos nixos-wsl.tar.gz
wsl -d NixOS
```

3. 首次构建：

```bash
nix shell nixpkgs#git
git clone <repo-url> ~/nix-config
cd ~/nix-config
sudo nixos-rebuild boot --flake .#wsl
```

4. 清理旧的 `nixos` 用户（可选）：

```bash
getent passwd nixos
sudo userdel --remove nixos
sudo rm -rf /home/nixos
```

之后日常重建：`just rebuild wsl`

## 仓库结构

```
flake.nix                      # 入口
hosts/                         # 主机特定配置
modules/
  ├── darwin/                  # macOS 模块
  ├── nixos/                   # NixOS 模块
  └── shared/                  # 共享模块
home/                          # Home Manager 配置
  ├── dev/                     # 开发工具
  └── shell/                   # Shell 配置
lib/default.nix                # 构建辅助函数
overlays/ + pkgs/              # 自定义包
```

配置层级：`hosts/*` → `modules/*` → `home/*`

## 日常使用

```bash
just rebuild <host>   # 重建系统
just update           # 更新所有 flake 输入
just up <input>       # 更新单个输入
just check            # 检查配置
just clean            # 清理旧 generation
just rollback         # 回滚（仅 NixOS）
just history          # 查看 profile 历史
just show             # 显示 flake 输出
```

`programs.nh.flake` 已指向 `~/nix-config`，所以也可直接：`nh os switch`、`nh home switch`、`nh clean all`，无需 `--flake` 参数。

## Shell

Fish + Starship + Atuin + Zoxide + FZF + Direnv，Catppuccin Mocha 主题。

常用自定义：
- fish abbreviation → `home/shell/fish.nix`
- 添加包 → 优先用 `programs.<name>.enable`（HM 模块），其次 `home/default.nix` 的 `home.packages`；语言/LSP 类放 `home/dev/languages.nix`
- Homebrew cask → `modules/darwin/default.nix`（共享）或 `hosts/<host>/default.nix`（单机）
- PATH 加目录 → `home.sessionPath`（在 `home/shell/fish.nix`）

## Environment

1Password CLI `op inject` 获取环境变量，本地缓存后离线可用。

模板文件 `~/.config/op-env/env.tpl` 由 `home/shell/fish.nix` 生成，仅包含 `op://` 引用，可安全提交。

Shell 启动时只读取本地缓存（`~/.cache/op-env/env.fish`），不联网。首次使用或密钥变更后需手动刷新：

```bash
op-env-refresh   # 从 1Password 获取并缓存（需联网）
op-env-clear     # 清除本地缓存
```

认证需要在 `~/.config/fish/local.fish`（gitignored）中设置：

```bash
set -gx OP_SERVICE_ACCOUNT_TOKEN "your-service-account-token"
```

未设置 token 时 `op-env-refresh` 会提示错误，不影响已有缓存的正常使用。
