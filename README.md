# Nix Config

nix-darwin + NixOS + Home Manager + Flakes 声明式管理两台 Mac + 一台 NixOS PC + 一台单臂透明代理网关。

## 设备

flake 目标、目录、`networking.hostName` 三者完全一致 —— 改任一项就全改。

| 设备 | 平台 | Flake 目标 / hostname / dir | 备注 |
|------|------|----------------------------|------|
| Mac Mini | aarch64-darwin | `awesome-mac-mini` | 常开机做 SSH/Tailscale 入口 |
| MacBook Air | aarch64-darwin | `awesome-macbook-air` | 笔记本，带刘海 |
| PC | x86_64-linux | `awesome-pc` | PVE VM 桌面，systemd-boot + KDE Plasma + NVIDIA 直通 |
| Mihomo Gateway | x86_64-linux | `mihomo-gateway` | 单臂透明代理，root-only，**不走** home-manager / fish / 1password / catppuccin |

## 快速开始

> 首次运行本仓任意 flake 命令（`nix run` / `nix develop` / `nixos-install` 等），nix 会提示忽略 flake 自带的 `nixConfig.extra-substituters`。临时加 `--accept-flake-config`，或在 `~/.config/nix/nix.conf` 写 `accept-flake-config = true` 后永久信任本仓 cache 设置。

### macOS

1. 安装 [Lix](https://lix.systems/)：

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

2. 克隆仓库并首次构建（`<host>` 取 `awesome-mac-mini` / `awesome-macbook-air`）：

```bash
git clone <repo-url> ~/nix-config
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake .#<host>
```

> Homebrew 由 `nix-homebrew` 声明式接管（`autoMigrate = true`），裸机直接装、已有 brew 自动接管，无需手工跑官方 install.sh。
>
> 首次 switch 前先在 App Store.app 登录 Apple ID，否则 `homebrew.masApps`（iPreview/Xnip）会装失败但不影响其余 bundle。brew 本体由 `nix-homebrew` 自带的 `brew-src` 提供（当前 6.x，随 `just update` 升 nix-homebrew 一起走），非官方 tap 在 `modules/darwin/default.nix` 标 `trusted = true` 以满足 brew 6.0 默认开启的 `HOMEBREW_REQUIRE_TAP_TRUST`。

之后日常重建：`just switch <host>`。

### PC

PVE VM NixOS 桌面（amd64），UEFI + systemd-boot + NetworkManager + KDE Plasma 6。首次用 NixOS minimal ISO 启动 VM 后，从本仓跑 `just install awesome-pc <vm-ip>` 远程首装；之后 `just deploy awesome-pc <vm-ip>` 或进系统后 `just switch awesome-pc` 重建。

<details>
<summary><b>首次装机完整流程</b>（点开展开）</summary>

#### 1. VM 启动安装环境

PVE VM 使用 OVMF/UEFI 启动，挂载 [NixOS minimal ISO (unstable)](https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso)。进 live 环境后提权并打开 SSH：

```bash
sudo -i
passwd
systemctl start sshd
ip -4 addr
```

这里的 root 密码只用于临时安装环境；用强临时密码，并确保 VM 安装网段可信。装完后清理本地 known_hosts，正式系统用声明式 SSH key 登录。

#### 2. 联网

- 有线：通常自动起来，`ping 1.1.1.1` 确认
- WiFi：`sudo systemctl start wpa_supplicant && wpa_cli`（或更友好的 `nmtui`）

#### 3. 确认目标磁盘

当前 `hosts/awesome-pc/disko.nix` 先按 `/dev/sda` 全盘安装。跑安装前务必在 live 环境确认目标盘：

```bash
lsblk -o NAME,MODEL,SIZE,TYPE
```

后续如果要避免盘符漂移，把 `hosts/awesome-pc/disko.nix` 里的 `diskDevice` 改成 `/dev/disk/by-id/...`。

#### 4. 远程首装

在本仓机器上执行：

```bash
just install awesome-pc <vm-ip>
```

底下走 `nixos-anywhere`：kexec → `disko` 全盘格式化 `/dev/sda` → 生成 `hosts/awesome-pc/hardware-configuration.nix` → install → reboot。生成内容含 VM 的 `boot.initrd.availableKernelModules` 等机器特有项，安装后记得提交。

#### 5. 首次登录 + 接管

```bash
ssh-keygen -R <vm-ip>
ssh imbytecat@<vm-ip>
git clone <repo-url> ~/nix-config
cd ~/nix-config
just switch awesome-pc
just lsp awesome-pc
```

如果首装时已经通过其他方式同步了仓库，跳过 `git clone`。`programs.nh.flake` 默认指向 `~/nix-config`。

#### 6. 提交硬件配置

```bash
git add hosts/awesome-pc/hardware-configuration.nix
git commit -m "awesome-pc: add hardware-configuration"
```

</details>

<details>
<summary><b>当前桌面 / GPU 配置</b></summary>

`hosts/awesome-pc/default.nix` 当前已经启用：

```nix
# KDE Plasma 6 + SDDM Wayland
services.xserver.enable = true;
services.displayManager.sddm.enable = true;
services.displayManager.sddm.wayland.enable = true;
services.desktopManager.plasma6.enable = true;

# RTX 4070 SUPER
hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
services.xserver.videoDrivers = [ "nvidia" ];
```

</details>

### Mihomo Gateway

单臂透明代理网关，**只做代理一件事**，不是日用 NixOS。模块隔离：

- 只共享 `modules/shared/nix.nix`（Lix + nix.settings + flake registry/nixPath）
- 不导入 `modules/shared/default.nix`（fish/1password/openssh）、`modules/nixos/`、home-manager、catppuccin
- 单用户 root，硬化 SSH（`PermitRootLogin = "prohibit-password"` + `PasswordAuthentication = false`），授权钥匙复用 `lib/default.nix` 的 `sshKeys`

**首次部署**（在任一日用机跑，目标机已用 NixOS installer 启动并允许 root SSH）：

```bash
just install mihomo-gateway <gateway-ip>
```

底下走 [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)：kexec → disko 全盘格式化 → install → reboot。`--build-on remote` 让目标机自己构建 closure，回避本机跨架构编译。磁盘布局在 `hosts/mihomo-gateway/disko.nix`（GPT + 512M ESP + 100% ext4 root），默认 `/dev/sda`，目标机不一致时 `lib.mkForce` 覆盖。

**装完后清一下本地 known_hosts**（host key 变了）：

```bash
ssh-keygen -R <gateway-ip>
```

**之后远程更新**：

```bash
just deploy mihomo-gateway <gateway-ip>
```

或登上去本机 rebuild：`just switch mihomo-gateway`。

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
  system = "x86_64-linux";  # 或 aarch64-linux（ARM VPS）
  extraModules = [
    ./modules/<purpose>
    ./hosts/<host>
  ];
};
```

部署：`just install <host> <remote>`（首装），之后 `just deploy <host> <remote>`（更新）。

## 仓库结构

```
flake.nix                      # 入口
hosts/                         # 主机特定配置（目录名 == flake 目标 == hostname）
  ├── awesome-mac-mini/        # 日用 Darwin
  ├── awesome-macbook-air/     # 日用 Darwin
  ├── awesome-pc/              # 日用 NixOS
  └── mihomo-gateway/          # 单臂透明代理网关 (default.nix + disko.nix)
modules/
  ├── desktop/                 # 桌面 GUI 应用（Darwin/NixOS desktop 显式导入）
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
- 日用桌面机：`hosts/*` → `modules/{shared,darwin|nixos}` + `modules/desktop` → `home/*`
- 日用无头 NixOS：`hosts/*` → `modules/{shared,nixos}` → `home/*`
- 服务器（如网关）：`hosts/<host>` + `modules/<purpose>` + `modules/shared/nix.nix`

## 日常使用

```bash
# 本机
just switch <host>           # 重建并激活本机系统（hostname 不匹配会拒绝）
just build <host>            # 仅构建不激活（产 result/，配合 just diff 看差异）
just boot <host>             # 仅注册下次启动 generation（kernel/initrd 更新需手动 reboot；仅 NixOS）
just rollback                # 回滚（仅 NixOS）

# 远程 NixOS 主机
just install <host> <remote> # 首次装机（nixos-anywhere）
just deploy <host> <remote>  # 远程更新（nixos-rebuild --target-host）

# 检查 / 诊断
just eval                    # eval 本平台所有 host 配置
just check                   # nix flake check
just dry <host>              # dry-run 看会编译/下载什么
just diff <host>             # 自动 build + 对比 /run/current-system 与 result/

# flake / 维护
just update                  # 更新所有 flake 输入
just up <input>              # 更新单个输入
just show                    # 列出 flake 输出
just history                 # profile 历史
just gc                      # GC（删 7 天前 generation）
just fmt                     # nix fmt 格式化所有 .nix
just repl                    # 带 nixpkgs 的 nix repl
just lsp <host>              # 生成 .vscode/settings.json，nixd 补全感知 host options
```

`programs.nh.flake` 已指向 `~/nix-config`，所以也可直接：`nh os switch`、`nh home switch`、`nh clean all`，无需 `--flake` 参数。

仓库带 `.envrc`（`use flake`），`home/shell/tools.nix` 已把 `~/nix-config` 加进 direnv whitelist，`cd` 进来即自动激活 dev shell，拿到 `just / jq / nixfmt / nixd / statix / nvd`，结果缓存到 `.direnv/`，flake.lock 不变则不重算。

裸机克隆后 direnv 还没装齐之前先手动一次：

```bash
nix develop      # 等价的临时 shell
```

## Shell

Fish + Starship + Atuin + Zoxide + FZF + Direnv，Catppuccin Mocha 主题。

常用自定义：
- fish abbreviation → `home/shell/fish.nix`
- 添加包 → 优先用 `programs.<name>.enable`（HM 模块），其次 `home/default.nix` 的 `home.packages`；语言/LSP 类放 `home/dev/languages.nix`
- 桌面 GUI 应用 → 多平台/共享的进 `modules/desktop/default.nix`；单机差异 cask 进 `hosts/<host>/default.nix`（如 `thaw` 在 `awesome-macbook-air`）
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
