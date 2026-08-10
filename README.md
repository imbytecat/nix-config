# Nix Config

nix-darwin + NixOS + Home Manager + Flakes 声明式管理一台 NixOS PC、一台 Mac、一个单臂透明代理网关和一台 OVH Docker 服务器。

Linux 为主、macOS 为辅：NixOS PC 是主力桌面，GUI 应用列表按平台分开维护（`modules/desktop/{darwin,nixos}.nix`），CLI/开发环境（`home/`）跨平台完全共享。服务器走 root-only 的最小闭包，业务按机器显式添加。

## 设备

flake 目标、目录、`networking.hostName` 三者完全一致 —— 改任一项就全改。

| 设备 | 平台 | Flake 目标 / hostname / dir | 备注 |
|------|------|----------------------------|------|
| PC | x86_64-linux | `awesome-pc` | **主力桌面**。实体机，systemd-boot + Plasma 6 Wayland + AMD GPU |
| MacBook Air | aarch64-darwin | `awesome-macbook-air` | 外出 + Xcode/Flutter 构建机，带刘海 |
| Mihomo Gateway | x86_64-linux | `mihomo-gateway` | 单臂透明代理，root-only，**不走** home-manager / fish / 1password / catppuccin |
| OVH KS-5 | x86_64-linux | `ovh-ks-5` | Xeon E3-1270 v6，2 × NVMe RAID1，root-only，只装 Docker + Compose |

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

### OVH KS-5

`ovh-ks-5` 是 root-only Docker 服务器，不导入 Home Manager、桌面、fish、1Password、catppuccin 或日用开发工具。Docker 包已自带 Compose 插件，使用 `docker compose`。

两块 NVMe（默认 `/dev/nvme0n1`、`/dev/nvme1n1`）由 `hosts/ovh-ks-5/disko.nix` 全盘重建：

- 每盘 1 MiB BIOS boot 分区，兼容 Legacy BIOS
- 两个 512 MiB ESP 组成 RAID1（metadata 1.0），挂载 `/boot/efi`
- 两个 2 GiB ext4 分区组成 RAID1（metadata 1.2），挂载 `/boot`
- 剩余空间组成 ext4 RAID1（metadata 1.2），挂载 `/`
- GRUB 同时支持 UEFI removable path 和 Legacy BIOS；主 IPv4 走 DHCP

先在 OVH 控制台切到 Rescue 模式，确认以 UEFI 启动且磁盘名无误：

```bash
ssh root@<server-ip> \
  'test -d /sys/firmware/efi && echo UEFI; lsblk -d -o NAME,SIZE,MODEL,SERIAL'
```

确认后从持有本仓的机器安装；此操作会清空两块 NVMe：

```bash
just install ovh-ks-5 <server-ip>
```

仓库预置的 `hosts/ovh-ks-5/hardware-configuration.nix` 是首次扫描入口。`just install` 会让 nixos-anywhere 用目标机的真实 `nixos-generate-config` 结果覆盖它；安装完成后检查并提交：

```bash
git add hosts/ovh-ks-5/hardware-configuration.nix
git commit -m "fix(ovh): 更新 hardware-configuration"
```

重启后验证：

```bash
ssh-keygen -R <server-ip>
ssh root@<server-ip>
cat /proc/mdstat
docker compose version
```

#### 备份与灾难恢复

服务按 dockge 的口径放：一个栈一个目录 `/opt/stacks/<name>/`，持久化全部 bind mount 在该目录内。于是"整台机器"等价于"这棵目录树"。

`hosts/ovh-ks-5/backup.nix` 用 `services.restic.backups.stacks` 每天 04:00 打一份快照：

- `paths`：`/opt/stacks` + `/var/lib/docker/volumes`（named volume 也只是目录，两种写法都兜住）
- 备份前遍历运行中的容器，凡是自带 `pg_dumpall` 的都导一份 `/opt/stacks/.dumps/<容器名>.sql.zst`，连 role 和密码一起带走。tar 活着的 PG 数据目录只是崩溃一致，逻辑 dump 才保证能恢复
- 某个库导失败不会取消快照：留下 `FAILED-<名字>` 标记，快照照常落地，之后把 unit 标红。绿色的残缺备份比红色的完整失败危险
- 保留 14 天 / 8 周 / 12 月；每次跑 `restic check --read-data-subset=2%` 抽检，约 50 天覆盖整个仓库
- restic 默认加密去重，所以每天全量 dump 只花增量空间

**为什么 PG 要额外 dump，文件级备份不够？** 因为"停机打包"和"运行中扫盘"是两件事。手工搬家时先 `docker compose down`，PG 干净关闭后数据目录本身自洽，直接打包搬走一定能用。但每天 04:00 的自动备份是**容器在跑**的：restic 逐个文件走几分钟，PG 同时在写，取到的不是某一瞬间而是一段时间的涂抹——`pg_control` 里的 checkpoint 指针来自 T0，某个 heap page 来自 T1，对应的 WAL 段可能已经被回收。这比崩溃更糟：真崩溃留下的是**某一瞬间**的状态，PG 重放 WAL 就能起来；涂抹出来的目录可能起不来，或者起来了但索引/页面已经错。

PG 官方只承认三种文件级备份：服务停机、`pg_backup_start()`/`pg_backup_stop()` 配 WAL 归档、或者文件系统级原子快照（LVM/ZFS/btrfs）。这台是 ext4 on mdraid，**没有原子快照能力**，所以走逻辑 dump：`pg_dumpall` 在一个事务的 MVCC 快照里跑，天然是一瞬间，还能跨大版本恢复。

数据目录的文件**仍然照常备份**（它就在 `/opt/stacks` 里），dump 只是额外的保险：恢复时先用数据目录，起不来才回放 dump。计划内搬家仍然推荐先 `docker compose down` 再手动跑一次备份，那份快照是字节级干净的。

异地仓库是 HostBrr Storagebox（DirectAdmin 账号，SSH/SFTP/rsync）。本仓公开，主机名/用户名/端口都不进 git，**全部塞进 `/etc/restic/repository` 那一行 URL**——`sftp://user@host:port//abs/path` 形式带端口，因此不需要 `/root/.ssh/config` 别名，也不需要预热 `known_hosts`（`backup.nix` 里的 `sftp.args` 已给 `StrictHostKeyChecking=accept-new`）。新机器上要手写的只有三样：

```bash
# 1. root 私钥（从 1Password 取回，或首次生成后把公钥装到 storagebox）
ssh-keygen -t ed25519 -N "" -C "restic@ovh-ks-5" -f /root/.ssh/id_ed25519
ssh-copy-id -p <box-port> <box-user>@<box-host>      # 只有这一步要输 box 密码

# 2+3. 仓库 URL 与仓库密码
install -d -m 0700 /etc/restic
echo 'sftp://<box-user>@<box-host>:<box-port>//home/<box-user>/restic/ovh-ks-5' > /etc/restic/repository
head -c 32 /dev/urandom | base64 > /etc/restic/password   # 换机时改成从 1Password 取回原值
: > /etc/restic/env          # sftp 不需要凭据环境变量，但 unit 要求该文件存在
chmod 600 /etc/restic/password /etc/restic/env

systemctl start restic-backups-stacks && restic-stacks snapshots
```

`restic-backups-stacks` 是 `Type=oneshot` 且 `TimeoutStartUSec=infinity`，大备份不会被 90s 默认超时掐掉。已在 ks-5 上删掉 `~/.ssh/config` 与 `known_hosts` 验证过：零 ssh 配置下备份成功、主机密钥被自动 pin、canary 文件从德国原样恢复。

`/etc/restic/password` 和 `/root/.ssh/id_ed25519` 是唯一必须活过这台机器的东西，存 1Password。仓库必须在异地：RAID1 只挡单盘故障，挡不住整机、机房或误删。

只用 ed25519。`ssh-ed25519` 从 OpenSSH 6.5（2014）起就是标准算法，storagebox 的 sshd 在 `server-sig-algs` 里明确带它；"只能 RSA" 是面板校验挑食的传闻，不是服务端限制。真遇上面板拒收就绕过面板，直接把公钥追加到 `~/.ssh/authorized_keys`。

链路实测（ks-5 → 德国 storagebox）：300 MiB 不可压数据 39s，约 7.7 MB/s；空仓库首跑连 `init` + `check` 花了 3m53s，几乎全是 SFTP 往返而不是带宽。首次搬入大量数据时可以临时加 `-o sftp.connections=8` 提并发。

`createWrapper` 会生成 `restic-stacks` 命令（环境变量已注入），换机或炸机后的恢复：

```bash
just install ovh-ks-5 <new-ip>          # 系统本身由本仓重建
# 补回 /root/.ssh/id_ed25519 与 /etc/restic/{repository,password,env}
restic-stacks snapshots
restic-stacks restore latest --target /
cd /opt/stacks/<name> && docker compose up -d
```

恢复出来的 PG 数据目录通常直接可用；若 PG 拒绝启动，清空该目录重建容器，再回放 dump：

```bash
zstd -dc /opt/stacks/.dumps/<容器名>.sql.zst | docker compose exec -T db psql -U postgres
```

### Mihomo Gateway

单臂透明代理网关，**只做代理一件事**，不是日用 NixOS。模块隔离：

- 走 `modules/nixos/server.nix`（= `base.nix` + 无头角色：SSH 硬化 / root-only / optimise / 关 fontconfig）
- GC 由跨平台 `modules/shared/gc.nix` 统一负责；bootloader 由 `modules/nixos/boot/systemd-boot.nix` 显式组合
- 不导入 `modules/shared/default.nix`（fish/1password）、`modules/nixos/dev.nix`（unfree/overlay/docker/catppuccin）、home-manager，闭包里没有任何日用组件
- 授权钥匙复用 `lib/default.nix` 的 `sshKeys`；网关业务全部在 `modules/gateway/`，机器独有事实（disko / virtio / 镜像源）在 `hosts/mihomo-gateway/`
- 目标机装机不依赖 GitHub：`just install` 用 lock 住的 nixos-anywhere + 国内镜像 substituter（发起端仍需本仓 checkout 与 flake.lock）；开机即带一份构建期已校验的 fallback 配置（`mode: direct` + IP 字面量 DoH），此时 LAN 已经能上网，之后把订阅链接写进 `/etc/mihomo/env` 即自动拉取生效

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

`mkServer` builder 通用，加新机器时：

1. 选择 `modules/nixos/boot/systemd-boot.nix`；双盘 RAID 启动用 `grub-raid.nix`
2. 需要独立业务模块时写 `modules/<purpose>/`
3. 写 `hosts/<host>/default.nix` 与 `disko.nix`
4. 裸机再加入并 import `hardware-configuration.nix`；文件必须先被 git 跟踪，`just install` 才会让 nixos-anywhere 在调用端工作树生成并纳入 flake
5. 在 `flake.nix` 添加：

```nix
<host> = mylib.mkServer {
  hostname = "<host>";
  system = "x86_64-linux";  # 或 aarch64-linux（ARM VPS）
  extraModules = [
    ./modules/nixos/boot/systemd-boot.nix
    ./modules/<purpose>
    ./hosts/<host>
  ];
};
```

无独立业务模块时直接省略 `./modules/<purpose>`。部署：`just install <host> <remote>`（首装），之后 `just deploy <host> <remote>`（更新）。

### 加新无头开发 NixOS 机

日用但不带桌面（SSH remote dev）：用 `mkNixos`，显式加入 boot 模块，`extraModules` **不加** `./modules/desktop/nixos.nix` 即可。`modules/nixos/base.nix` + `dev.nix` 已含 locale、docker、nix-ld、用户，home-manager 全量生效，SSH 上去 shell/git/nvim 体验与桌面机一致。

```nix
<host> = mylib.mkNixos {
  hostname = "<host>";
  system = "x86_64-linux";
  username = "imbytecat";
  extraModules = [
    inputs.disko.nixosModules.disko  # 如走 nixos-anywhere 首装
    ./modules/nixos/boot/systemd-boot.nix
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
  ├── mihomo-gateway/          # 单臂透明代理网关 (default.nix + disko.nix)
  └── ovh-ks-5/                # OVH Docker 裸机 (default.nix + disko.nix + hardware-configuration.nix)
modules/
  ├── desktop/                 # 平台桌面角色，故意分开维护、互不迁就
  │   ├── darwin.nix           #   macOS GUI（brew casks + MAS）
  │   └── nixos.nix            #   NixOS GUI（Plasma 6 + 桌面应用 + fcitx5/rime + 罗技外设）
  ├── darwin/                  # macOS 模块
  ├── nixos/                   # NixOS 阶梯：base.nix → dev.nix（日用）/ server.nix（无头服务器）
  │   └── boot/                # 显式 boot adapter：systemd-boot / RAID GRUB
  ├── gateway/                 # 网关模块 (mihomo + tproxy + 单臂 networking)
  └── shared/                  # 跨平台共享 (gc/nix/fonts/fish/1password；SSH 基线在 nixos/base.nix)
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
| NixOS 桌面 | `hosts/*` + `boot/systemd-boot.nix` → `modules/shared` + `modules/nixos/{base,dev}.nix` + `modules/desktop/nixos.nix` → `home/*` | awesome-pc |
| NixOS 无头开发 | 同上去掉 `modules/desktop/nixos.nix` | （预留） |
| NixOS 服务器 | `hosts/<host>` + `boot/<adapter>` + 可选 `modules/<purpose>` + `modules/nixos/server.nix`（mkServer，无 HM） | mihomo-gateway、ovh-ks-5 |

`modules/nixos/` 是一条阶梯：`base.nix`（所有 NixOS 主机都成立的 locale、SSH、zram 等事实）→ 上面二选一叠 `dev.nix`（日用开发）或 `server.nix`（无头服务器）→ 桌面再叠 `modules/desktop/nixos.nix`。bootloader 是机器启动策略，不属于角色基线，因此从 `base.nix` 拆出并在每个 host 的 flake 组合中显式选择。

所有系统都导入 `modules/shared/gc.nix`：每周自动执行 `nix-collect-garbage --delete-older-than 30d`；Linux 用 systemd timer，Darwin 用 launchd calendar interval。

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
just update                  # 更新可自动维护依赖（flake 输入 + Orca）
just up <input>              # 更新单个输入
just show                    # 列出 flake 输出
just history                 # profile 历史
just gc                      # GC（删 7 天前 generation）
just fmt                     # treefmt 格式化整个仓库（等价于裸跑 nix fmt）
just lint                    # actionlint + statix + deadnix
just repl                    # 带 nixpkgs 的 nix repl
```

GitHub Actions 每周运行同一更新与检查流程，通过后创建/刷新 PR 并自动 squash 合并；Rime、字体和 kexec 镜像只报告上游状态，仍需人工确认。

`programs.nh.flake` 已指向 `~/nix-config`，所以也可直接：`nh os switch`、`nh home switch`、`nh clean all`，无需 `--flake` 参数。

仓库带 `.envrc`（`use flake`），`home/shell/tools.nix` 已把 `~/nix-config` 加进 direnv whitelist，`cd` 进来即自动激活 dev shell，拿到 `just / nixd / actionlint / statix / deadnix / nix-update / nvd / nix-tree / treefmt`，结果缓存到 `.direnv/`，flake.lock 不变则不重算。

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
