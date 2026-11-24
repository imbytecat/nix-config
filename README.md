# Nix Config

用 Nix Flakes、NixOS、nix-darwin 和 Home Manager 管理个人设备。

## 设备

| Host | 用途 | 平台 |
|------|------|------|
| `awesome-pc` | 主力 Plasma 桌面 | x86_64-linux |
| `homelab-server` | root-only Docker VM（Proxmox VE） | x86_64-linux |
| `awesome-macbook-air` | 移动与 Apple 平台构建 | aarch64-darwin |
| `mihomo-gateway` | 单臂透明代理网关 | x86_64-linux |
| `ovh-ks-5` | root-only Docker 服务器 | x86_64-linux |
| `agent-server` | T3 Code daemon，服务只经 tailnet | x86_64-linux |

flake 目标、`hosts/<host>` 目录和 `networking.hostName` 必须同名。

## 日常使用

```bash
just switch <host>                 # 构建并激活本机；hostname 不匹配会拒绝
just build <host>                  # 仅构建
just diff <host>                   # 构建并对比当前系统
just check                         # 格式、lint、全部 host eval

just deploy <host> <remote>        # 更新远程 NixOS
just deploy-boot <host> <remote>   # 仅注册远程下次启动 generation
just update                        # 更新 flake 输入
```

`just` 可查看全部命令。进入仓库后使用 `nix develop` 获取项目工具。

每周依赖更新工作流使用同一入口，构建 WowType 并通过 `just check` 后自动合并；
字体和 kexec 引导镜像（`kexec-bootstrap`）的 hash 仍需人工维护。

首次运行 flake 命令若提示忽略仓库 cache，添加 `--accept-flake-config`，或在
`~/.config/nix/nix.conf` 写入：

```nix
accept-flake-config = true
```

### 中文输入

`awesome-pc` 使用 Fcitx5 + [WowType](https://github.com/Gloridust/WowType) 小鹤双拼；单击 CapsLock 切换中英，`nihc` 输入“你好”。
配置在 `modules/nixos/input-method.nix`。`~/.config/fcitx5/conf/wowtype.conf` 由 Nix 强制接管：
设置界面里的改动会在下次 switch 时被覆盖，长期设置写进该模块；自定义词在 `~/.local/share/wowtype/custom.tsv`，不受影响。
WowType 跟随上游 `release` 分支，随 `just update` 更新，没有二进制缓存，每次升级都在本地编译。
switch 不会重启 fcitx5，插件升级后重新登录生效；KDE Wayland 下不要用 `fcitx5 -r` 重启，否则之后新开的程序无法输入。

### 显卡熄屏功耗

`awesome-pc` 在 `hosts/awesome-pc/default.nix` 通过 `amdgpu.ppfeaturemask=0xfff73fff`
关闭 GFXOFF，绕过 [Navi 33 空闲高功耗问题](https://gitlab.freedesktop.org/drm/amd/-/issues/3549)。
掩码由当前默认值 `0xfff7bfff` 仅清除 `0x8000` 得到，不启用其他特性。
这是牺牲深度省电的临时规避：本机熄屏实测由约 130W 降至 26–28W，仍可能正常温控启停风扇。
`just switch awesome-pc` 后须重启使启动参数生效；上游修复后移除此参数并重启恢复默认。

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

安装会先用 `ssh-copy-id` 把本机公钥装进目标机（rescue 只有密码时会提示输入），再 kexec 两次：第一次进上游镜像拿到 Nix，第二次进本仓按目标机 LTS 内核构建的镜像，再分区安装。RAID 阵列必须由不比目标新的内核创建，否则目标机组装不了。

安装完成后清除旧 SSH host key：

```bash
ssh-keygen -R <remote>
```

关键机器差异：

- `awesome-pc`：单盘 UEFI + systemd-boot；磁盘默认使用 `hosts/awesome-pc/disko.nix` 中的 by-id。
- `homelab-server`：PVE QEMU VM，默认 `/dev/sda`；PVE 呈现其他设备时先改 host 内默认值。
- `mihomo-gateway`：默认 `/dev/sda`，安装后必须补 `/etc/mihomo/env`。
- `ovh-ks-5`：两块 NVMe 全盘组成 RAID1；从 OVH Rescue 安装前确认以 UEFI 启动。
- `agent-server`：与 `ovh-ks-5` 同款两块 NVMe，但 root 是 RAID0（ESP、`/boot` 仍为 RAID1），且不做备份：坏任一块盘即重装并丢失数据。

### Mihomo 订阅

```bash
ssh root@<gateway-ip> "cat > /etc/mihomo/env << 'EOF'
CONFIG_URL=https://your-subscription-url
SECRET=your-api-password
EOF"
```

文件变化会自动触发订阅拉取、净化、校验与 Mihomo 重启。

### T3 Code（agent-server）

开发机和服务器共用 Home Manager 的 `agent` 角色，包含 Codex、Claude Code、OMP、Pi、DSH、插件、skills 和 T3 daemon。服务器以 `t3code` 账号运行，家目录是 `/var/lib/t3code`，重启后由 systemd 用户服务自动启动。

首次部署后，以 root 在服务器上启用 tailnet HTTPS。下面的映射会跨重启保留：

```bash
tailscale up
tailscale serve --bg http://127.0.0.1:3773
```

从 Mac 或 PC 运行 `just deploy agent-server <remote>`。首次部署会配置解密身份，以后随系统部署更新网关和 Exa 凭据。T3 服务启动时同步 Codex 登录；空机仍可先配对，首次部署后模型可用。密钥轮换见下文「Agent 密钥」。

在服务器上生成一次性配对链接，把 `<tailnet>` 替换为 `tailscale serve status` 显示的域名后缀。手机或桌面端连上同一 tailnet，在 **Add environment** 粘贴链接：

```bash
sudo -Hu t3code /etc/profiles/per-user/t3code/bin/t3 auth pairing create \
  --base-url 'https://agent-server.<tailnet>.ts.net'
```

### OVH 备份与灾难恢复

业务数据放在 `/opt/stacks`。系统每天用 restic 备份该目录、Docker named volumes，并为运行中的 PostgreSQL 容器生成逻辑 dump。

以下内容不进 git，必须保存在 1Password：

- `/root/.ssh/id_ed25519`
- `/etc/restic/repository`
- `/etc/restic/password`

`/etc/restic/repository` 使用 `sftp://user@host:port//abs/path`。恢复已有仓库时先确认能读取历史；服务不会自动创建仓库，避免地址写错后静默备份到新仓库：

```bash
restic-stacks snapshots
systemctl start restic-backups-stacks
```

只有首次创建全新空仓库时手动运行 `restic-stacks init`。

重建机器后补回上述文件，停止 Docker 再恢复 named volumes：

```bash
just install ovh-ks-5 <new-ip>
restic-stacks snapshots
systemctl stop docker.service docker.socket
restic-stacks restore latest --target /
systemctl start docker.service
cd /opt/stacks/<name> && docker compose up -d
```

若 PostgreSQL 数据目录无法启动，重建空数据库后回放：

```bash
zstd -dc /opt/stacks/.dumps/<container>.sql.zst \
  | docker compose exec -T db psql -X -U postgres
```

RAID1 不是备份；restic 仓库必须位于异地。

## Agent 密钥

Mac、PC 和 agent-server 共用 `secrets/agents.yaml` 的一个 SOPS 接收者，由日常登录的 Ed25519 私钥派生。Mac 或 PC 上有对应的 `~/.ssh/id_ed25519` 就能编辑。日常机使用 `agents.env`、`daily.env` 和 Tea 配置，服务器只给 `t3code` 提供 `agents.env`。两个 env 块保持 shell 和 systemd 均可读取的 dotenv 格式。

```sh
just secrets                         # 编辑并保存密文
just switch awesome-macbook-air      # 在 Mac 上激活；PC 上换成 awesome-pc
just deploy agent-server <remote>    # 从 Mac 或 PC 更新 NixOS 服务器
```

将密文提交到 Git 以便另一台开发机取得更新。新终端会读取新值，已打开的交互 shell 可运行 `exec zsh`。更新密文后，部署会重启 T3 并同步 Codex 凭据。服务重启可能中断正在运行的 agent 会话。

首次 `switch`、`boot` 或 `deploy` 会从调用端的 SSH 私钥派生 age 解密身份，写入目标机的 `/var/lib/sops-nix/agents-key.txt`（root，0600）。远程首次登记会核对 SSH 主机身份和主机名。重装后用同一把私钥重新部署即可。拥有任一目标机的 root 权限即可解密整份密文；请备份原始 SSH 私钥。NixOS 首装后先运行一次 `just deploy`，安装器不携带解密身份。

从 1Password 迁移时，首次部署验证成功后可从 `~/.config/zsh/local.zsh` 删除 `OP_SERVICE_ACCOUNT_TOKEN` 并撤销旧 service account。迁移保留原来的 op-env 缓存和服务器手写 env，旧 generation 回滚时仍可读取。
