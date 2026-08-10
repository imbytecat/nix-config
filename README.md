# Nix Config

用 Nix Flakes、NixOS、nix-darwin 和 Home Manager 管理个人设备。

## 设备

| Host | 用途 | 平台 |
|------|------|------|
| `awesome-pc` | 主力 Plasma 桌面 | x86_64-linux |
| `awesome-macbook-air` | 移动与 Apple 平台构建 | aarch64-darwin |
| `mihomo-gateway` | 单臂透明代理网关 | x86_64-linux |
| `ovh-ks-5` | root-only Docker 服务器 | x86_64-linux |

flake 目标、`hosts/<host>` 目录和 `networking.hostName` 必须同名。

## 日常使用

```bash
just switch <host>                 # 构建并激活本机；hostname 不匹配会拒绝
just build <host>                  # 仅构建
just diff <host>                   # 构建并对比当前系统
just check                         # 格式、lint、全部 host eval

just deploy <host> <remote>        # 更新远程 NixOS
just deploy-boot <host> <remote>   # 仅注册远程下次启动 generation
just update                        # 更新 flake 输入与自动维护项
```

`just` 可查看全部命令。进入仓库后使用 `nix develop` 获取项目工具。

首次运行 flake 命令若提示忽略仓库 cache，添加 `--accept-flake-config`，或在
`~/.config/nix/nix.conf` 写入：

```nix
accept-flake-config = true
```

## 安装与恢复

### macOS

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
git clone <repo-url> ~/nix-config
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake .#awesome-macbook-air
```

首次 switch 前先登录 App Store，否则 MAS 应用会安装失败。之后使用：

```bash
just switch awesome-macbook-air
```

### NixOS

目标机先启动 NixOS installer/rescue，联网并开放 root SSH，再从持有本仓的机器运行：

```bash
just install <host> <remote>
```

> `just install` 会按 `hosts/<host>/disko.nix` 重建整盘，目标数据全部丢失。执行前必须核对 host、磁盘型号、容量和序列号。

安装完成后清除旧 SSH host key：

```bash
ssh-keygen -R <remote>
```

关键机器差异：

- `awesome-pc`：单盘 UEFI + systemd-boot；磁盘默认使用 `hosts/awesome-pc/disko.nix` 中的 by-id。
- `mihomo-gateway`：默认 `/dev/sda`，安装后必须补 `/etc/mihomo/env`。
- `ovh-ks-5`：两块 NVMe 全盘组成 RAID1；从 OVH Rescue 安装前确认以 UEFI 启动。

### Mihomo 订阅

```bash
ssh root@<gateway-ip> "cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-subscription-url
SECRET=your-api-password
EOF"
```

文件变化会自动触发订阅拉取、净化、校验与 Mihomo 重启。

### OVH 备份与灾难恢复

业务数据放在 `/opt/stacks`。系统每天用 restic 备份该目录、Docker named volumes，并为运行中的 PostgreSQL 容器生成逻辑 dump。

以下内容不进 git，必须保存在 1Password：

- `/root/.ssh/id_ed25519`
- `/etc/restic/repository`
- `/etc/restic/password`

`/etc/restic/repository` 使用 `sftp://user@host:port//abs/path`；另需创建空文件 `/etc/restic/env`。

```bash
systemctl start restic-backups-stacks
restic-stacks snapshots
```

重建机器后补回上述文件，再恢复：

```bash
just install ovh-ks-5 <new-ip>
restic-stacks restore latest --target /
cd /opt/stacks/<name> && docker compose up -d
```

若 PostgreSQL 数据目录无法启动，重建空数据库后回放：

```bash
zstd -dc /opt/stacks/.dumps/<container>.sql.zst \
  | docker compose exec -T db psql -U postgres
```

RAID1 不是备份；restic 仓库必须位于异地。

## 本地密钥

在 `~/.config/fish/local.fish` 设置 1Password Service Account token：

```fish
set -gx OP_SERVICE_ACCOUNT_TOKEN "your-service-account-token"
```

然后手动刷新本地环境变量缓存：

```bash
op-env-refresh
```
