# Nix Config

nix-darwin + NixOS-WSL + Home Manager + Flakes 声明式管理三台日用设备 + 一台单臂透明代理网关。

## 设备

| 设备 | 平台 | Flake 目标 | 主机名 | 备注 |
|------|------|-----------|--------|------|
| Mac Mini | aarch64-darwin | `mac-mini` | awesome-mac-mini | 日用 |
| MacBook Air | aarch64-darwin | `macbook-air` | awesome-macbook-air | 日用 |
| Windows PC (WSL) | x86_64-linux | `wsl` | awesome-wsl | 日用 |
| Mihomo Gateway | x86_64-linux | `gateway` | mihomo-gateway | 单臂透明代理，root-only，**不走** home-manager / fish / 1password / catppuccin |

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

### Mihomo Gateway

单臂透明代理网关，**只做代理一件事**，不是日用 NixOS。模块隔离：

- 只共享 `modules/shared/nix.nix`（Lix + nix.settings + flake registry/nixPath）
- 不导入 `modules/shared/default.nix`（fish/1password/openssh）、`modules/nixos/`、home-manager、catppuccin
- 单用户 root，硬化 SSH（`PermitRootLogin = "prohibit-password"` + `PasswordAuthentication = false`），授权钥匙复用 `lib/default.nix` 的 `sshKeys`

**首次部署**（在工作机跑，目标机已用 NixOS installer 启动并允许 root SSH）：

```bash
just install gateway <gateway-ip>
```

底下走 [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)：kexec → disko 全盘格式化 → install → reboot。`--build-on remote` 让目标机自己构建 closure，回避本机跨架构编译。磁盘布局在 `hosts/mihomo-gateway/disko.nix`（GPT + 512M ESP + 100% ext4 root），默认 `/dev/sda`，目标机不一致时 `lib.mkForce` 覆盖。

**装完后清一下本地 known_hosts**（host key 变了）：

```bash
ssh-keygen -R <gateway-ip>
```

**之后远程更新**：

```bash
just deploy gateway <gateway-ip>
```

或登上去本机 rebuild：`just rebuild gateway`。

**部署完写订阅**：

```bash
ssh root@<gateway-ip> "cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-subscription-url
SECRET=your-api-password
EOF"
```

`mihomo-subscribe.path` 监听文件变化自动触发拉订阅 → 净化 → 合并 → 验证 → 重启 mihomo。详见 `AGENTS.md` 的「Mihomo Gateway」段与 `.agents/skills/mihomo/SKILL.md`。

### 加新远程 NixOS 服务器

`mkServer` builder 通用，加新机器三步走：

1. 写 `modules/<purpose>/`（服务相关 NixOS 配置，如 mihomo + tproxy）
2. 写 `hosts/<host>/{default,disko}.nix`（boot/openssh/timezone/disko 等 host-level 配置）
3. 在 `flake.nix` 添加：

```nix
<host> = mylib.mkServer {
  hostname = "<host>";
  extraModules = [
    ./modules/<purpose>
    ./hosts/<host>
  ];
};
```

部署：`just install <host> <ip>`（首装），之后 `just deploy <host> <ip>`（更新）。

## 仓库结构

```
flake.nix                      # 入口
hosts/                         # 主机特定配置
  ├── mac-mini/ macbook-air/   # 日用 Darwin
  ├── wsl/                     # 日用 NixOS-WSL
  └── mihomo-gateway/          # 单臂透明代理网关 (default.nix + disko.nix)
modules/
  ├── darwin/                  # macOS 模块
  ├── nixos/                   # NixOS 日用模块
  ├── gateway/                 # 网关模块 (mihomo + tproxy + 单臂 networking)
  └── shared/                  # 跨平台共享 (fonts/nix/fish/openssh/1password)
home/                          # Home Manager 配置（只用于日用机）
  ├── dev/                     # 开发工具
  └── shell/                   # Shell 配置
lib/default.nix                # mkDarwin / mkNixos / mkServer 构建器
overlays/ + pkgs/              # 自定义包
.agents/skills/                # Agent skills (Mihomo TPROXY 排查手册等)
```

配置层级：
- 日用机：`hosts/*` → `modules/{shared,darwin|nixos}` → `home/*`
- 服务器（如网关）：`hosts/<host>` + `modules/<purpose>` + `modules/shared/nix.nix`

## 日常使用

```bash
# 本机
just rebuild <host>          # 重建本机系统（mac-mini / macbook-air / wsl / gateway 在网关本机时）
just rollback                # 回滚（仅 NixOS）
just history                 # 查看 profile 历史

# 远程 NixOS 主机
just install <host> <ip>     # 首次装机（nixos-anywhere）
just deploy <host> <ip>      # 远程更新（nixos-rebuild --target-host）

# flake / 维护
just check                   # eval 全部主机配置
just update                  # 更新所有 flake 输入
just up <input>              # 更新单个输入
just show                    # 列出 flake 输出
just clean                   # 清理旧 generation
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
