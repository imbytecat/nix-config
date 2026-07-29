# Nix Config

nix-darwin + NixOS + Home Manager + Flakes 声明式管理一台 NixOS PC + 一台 Mac + 一台单臂透明代理网关。

Linux 为主、macOS 为辅：NixOS PC 是主力桌面，GUI 应用列表按平台分开维护（`modules/desktop/{darwin,nixos}.nix`），CLI/开发环境（`home/`）跨平台完全共享，SSH 到任何一台机器 shell/git/nvim 体验一致。

## 设备

flake 目标、目录、`networking.hostName` 三者完全一致 —— 改任一项就全改。

| 设备 | 平台 | Flake 目标 / hostname / dir | 备注 |
|------|------|----------------------------|------|
| PC | x86_64-linux | `awesome-pc` | **主力桌面**。实体机，systemd-boot + Plasma 6 Wayland + AMD GPU |
| MacBook Air | aarch64-darwin | `awesome-macbook-air` | 外出 + Xcode/Flutter 构建机，带刘海 |
| Mihomo Gateway | x86_64-linux | `mihomo-gateway` | 单臂透明代理，root-only，**不走** home-manager / fish / 1password / catppuccin |

## 快速开始

> 首次运行本仓任意 flake 命令（`nix run` / `nix develop` / `nixos-install` 等），nix 会提示忽略 flake 自带的 `nixConfig.extra-substituters`。临时加 `--accept-flake-config`，或在 `~/.config/nix/nix.conf` 写 `accept-flake-config = true` 后永久信任本仓 cache 设置。

### macOS

1. 安装 [Lix](https://lix.systems/)：

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

2. 克隆仓库并首次构建：

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

`awesome-pc` 是 UEFI + systemd-boot + Plasma 6 Wayland 桌面。磁盘布局由 `hosts/awesome-pc/disko.nix` 声明：1 GiB ESP、ext4 root、zram，无磁盘 swap。

> 首装会清空 `disko.nix` 指向的整块磁盘。执行前必须核对型号、容量、序列号和 by-id。

#### 首装（推荐：nixos-anywhere）

目标机启动 [NixOS minimal ISO](https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso)，联网后开放 SSH：

```bash
sudo -i
passwd
systemctl start sshd
ip -4 addr
```

在持有本仓的另一台机器运行：

```bash
just install awesome-pc <live-ip>
```

`nixos-anywhere` 会运行 disko、生成 `hardware-configuration.nix`、安装并重启。若硬件配置有变化，确认后提交：

```bash
git add hosts/awesome-pc/hardware-configuration.nix
git commit -m "fix(awesome-pc): 更新 hardware-configuration"
```

#### 本机 Live 安装（备用）

先确认目标磁盘：

```bash
lsblk -o NAME,MODEL,SIZE,TYPE,SERIAL
ls -l /dev/disk/by-id/
```

然后运行 `disko-install`。Live 环境里没有本仓 checkout，所以走 GitHub 上**已推送**的那份
（`#disko-install` 与 `#awesome-pc` 都取自远端，本地未推的 commit 不生效）：

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run --accept-flake-config github:imbytecat/nix-config#disko-install -- \
  --flake github:imbytecat/nix-config#awesome-pc \
  --mode format \
  --write-efi-boot-entries \
  --disk main /dev/disk/by-id/nvme-HS-SSD-C2000Pro_1024G_AA000000000000001070
reboot
```

`disko-install` 故意忽略配置里的 `device`，必须显式传 `--disk main <device>`。Live 环境没有该 by-id 时，只替换命令最后的设备路径，例如 `/dev/nvme0n1`。该命令没有额外确认提示。

#### 首次登录

```bash
ssh-keygen -R <ip>
ssh imbytecat@<ip>
git clone <repo-url> ~/nix-config
cd ~/nix-config
just switch awesome-pc
```

桌面角色在 `modules/desktop/nixos.nix`，AMD GPU 和 CachyOS 内核等硬件配置在 `hosts/awesome-pc/default.nix`。

### Mihomo Gateway

单臂透明代理网关，**只做代理一件事**，不是日用 NixOS。模块隔离：

- 走 `modules/nixos/server.nix`（= `base.nix` + 无头角色：SSH 硬化 / root-only / `nix.gc` / generation 上限 / zram / 关 fontconfig）
- 不导入 `modules/shared/default.nix`（fish/1password）、`modules/nixos/dev.nix`（unfree/overlay/docker/catppuccin）、home-manager，闭包里没有任何日用组件
- 授权钥匙复用 `lib/default.nix` 的 `sshKeys`；网关业务全部在 `modules/gateway/`，机器独有事实（disko / virtio / 镜像源）在 `hosts/mihomo-gateway/`
- 从零装机不依赖 GitHub：`just install` 用 lock 住的 nixos-anywhere + 国内镜像 substituter；开机即带一份构建期已校验的 fallback 配置（`mode: direct` + IP 字面量 DoH），此时 LAN 已经能上网，之后把订阅链接写进 `/etc/mihomo/env` 即自动拉取生效

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

### 加新无头开发 NixOS 机

日用但不带桌面（SSH remote dev）：用 `mkNixos`，`extraModules` **不加** `./modules/desktop/nixos.nix` 即可。`modules/nixos/base.nix` + `dev.nix` 已含 locale、docker、nix-ld、用户，home-manager 全量生效，SSH 上去 shell/git/nvim 体验与桌面机一致。

```nix
<host> = mylib.mkNixos {
  hostname = "<host>";
  system = "x86_64-linux";
  username = "imbytecat";
  extraModules = [
    inputs.disko.nixosModules.disko  # 如走 nixos-anywhere 首装
    ./hosts/<host>
  ];
};
```

## 仓库结构

```
flake.nix                      # 入口
hosts/                         # 主机特定配置（目录名 == flake 目标 == hostname）
  ├── awesome-macbook-air/     # 日用 Darwin
  ├── awesome-pc/              # 日用 NixOS
  └── mihomo-gateway/          # 单臂透明代理网关 (default.nix + disko.nix)
modules/
  ├── desktop/                 # 平台桌面角色，故意分开维护、互不迁就
  │   ├── darwin.nix           #   macOS GUI（brew casks + MAS）
  │   └── nixos.nix            #   NixOS GUI（Plasma 6 + 桌面应用 + fcitx5/rime + 罗技外设）
  ├── darwin/                  # macOS 模块
  ├── nixos/                   # NixOS 阶梯：base.nix → dev.nix（日用）/ server.nix（无头服务器）
  ├── gateway/                 # 网关模块 (mihomo + tproxy + 单臂 networking)
  └── shared/                  # 跨平台共享 (fonts/nix/fish/openssh/1password)
home/                          # Home Manager 配置（只用于日用机，跨平台 ~100% 共享）
  ├── dev/                     # 开发工具
  └── shell/                   # Shell 配置
lib/default.nix                # mkDarwin / mkNixos / mkServer 构建器
overlays/ + pkgs/              # 自定义包
.agents/skills/                # Agent skills (Mihomo TPROXY 排查手册等)
```

三种 NixOS 场景 + Darwin 的配置层级：

| 场景 | 组成 | 示例 |
|------|------|------|
| Darwin 桌面 | `hosts/*` → `modules/{shared,darwin}` + `modules/desktop/darwin.nix` → `home/*` | MacBook Air |
| NixOS 桌面 | `hosts/*` → `modules/shared` + `modules/nixos/{base,dev}.nix` + `modules/desktop/nixos.nix` → `home/*` | awesome-pc |
| NixOS 无头开发 | 同上去掉 `modules/desktop/nixos.nix` | （预留） |
| NixOS 服务器 | `hosts/<host>` + `modules/<purpose>` + `modules/nixos/server.nix`（mkServer，无 HM） | mihomo-gateway |

`modules/nixos/` 是一条阶梯：`base.nix`（所有 NixOS 主机都成立的事实）→ 上面二选一叠 `dev.nix`（日用开发）或 `server.nix`（无头服务器）→ 桌面再叠 `modules/desktop/nixos.nix`。判据：一个事实只要有一种角色不需要，就不许放进 `base.nix`。

共享边界：`home/`（shell/git/nvim/AI 工具链）跨平台共享，SSH 到任何一台日用机体验一致；GUI 应用列表按平台分开演化——brew/MAS 与 nixpkgs 的包名、机制、可用性差异太大，强行对齐得不偿失。

## 日常使用

```bash
# 本机
just switch <host>           # 重建并激活本机系统（hostname 不匹配会拒绝）
just build <host>            # 仅构建不激活（产 result/，配合 just diff 看差异）
just boot <host>             # 仅注册下次启动 generation（kernel/initrd 更新需手动 reboot；仅 NixOS）
just rollback                # 回滚（仅 NixOS）

# NixOS 首装 / 远程
just install <host> <remote> # 远程首装（nixos-anywhere）
just deploy <host> <remote>  # 远程更新（nixos-rebuild --target-host）
just deploy-boot <host> <remote> # 远程更新但仅注册下次启动（kernel/initrd 类更新）

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
```

`programs.nh.flake` 已指向 `~/nix-config`，所以也可直接：`nh os switch`、`nh home switch`、`nh clean all`，无需 `--flake` 参数。

仓库带 `.envrc`（`use flake`），`home/shell/tools.nix` 已把 `~/nix-config` 加进 direnv whitelist，`cd` 进来即自动激活 dev shell，拿到 `just / nixfmt / nixd / statix / nvd`，结果缓存到 `.direnv/`，flake.lock 不变则不重算。

裸机克隆后 direnv 还没装齐之前先手动一次：

```bash
nix develop      # 等价的临时 shell
```

## Shell

Fish + Starship + Atuin + Zoxide + FZF + Direnv，Catppuccin Mocha 主题。

常用自定义：
- fish abbreviation → `home/shell/fish.nix`
- 添加包 → 优先用 `programs.<name>.enable`（HM 模块），其次 `home/default.nix` 的 `home.packages`；语言/LSP 类放 `home/dev/languages.nix`
- 桌面 GUI 应用 → macOS cask 进 `modules/desktop/darwin.nix`，NixOS 桌面应用进 `modules/desktop/nixos.nix`（两边独立维护，不要求对齐）；单机差异 cask 进 `hosts/<host>/default.nix`（如 `thaw` 在 `awesome-macbook-air`）
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
