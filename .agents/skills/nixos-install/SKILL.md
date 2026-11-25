---
name: nixos-install
description: "本仓 NixOS 首装、重装与首次部署流程（just install、两次 kexec、disko 布局、hardware config、SOPS 解密身份）。修改 scripts/install.sh、modules/flake/install.nix、磁盘布局，或给新机器装系统前先读。触发词: install, nixos-anywhere, kexec, disko, raid, hardware-configuration, 首装, 重装。"
---

# NixOS 安装与首次部署

## 入口

- 首选从另一台机器运行 `just install <host> <remote>`（`scripts/install.sh`：nixos-anywhere，`--build-on remote`）。目标机先进 NixOS installer 或 rescue，联网并开放 root SSH；脚本先 `ssh-copy-id`，rescue 只有密码时会提示输入。
- 备用：在 Live 环境本机直接运行本仓 `packages.x86_64-linux.disko-install`，显式传 `--flake`、`--disk` 和 `--write-efi-boot-entries`。`disko-install` **忽略** flake 里的 `device`，强制以 CLI `--disk <name> <path>` 为准（见上游 install-cli.nix）；设备对不上时只替换 CLI 路径。
- 之后用 `just deploy <host> <remote>` / `just deploy-boot <host> <remote>` 更新。装完 SSH host key 会变：`ssh-keygen -R <remote>`。

## hardware config

- 只有 `hosts/<host>/hardware-configuration.nix` 被 git 跟踪时，`just install` 才让 nixos-anywhere 重新生成：未跟踪的文件不会进目标 build。生成结果在目标 build 之前覆盖调用端工作区里的该文件；装完提交目标机的扫描结果。本地安装使用已提交的版本。
- `ovh-ks-5` 与 `awesome-devbox` 跟踪的 hardware config 就是首装生成目标，两者内容相同。

## 两次 kexec

创建 md 阵列的内核决定哪些内核能组装它：6.19+ 往超级块写 logical-block-size 字段，旧内核拒绝组装；nixos-images 的 kexec 镜像却用最新内核（`installer.nix` 引入 `latest-zfs-kernel.nix`；上游 nixos-anywhere#673、disko#1276 仍未关闭）。所以 `scripts/install.sh`：

1. 用 nixos-anywhere 引导 `kexec-bootstrap`。它是上游镜像，只为在目标机上拿到 Nix；上游重传资产时 hash 照 got 更新即可。
2. 经 `ssh-ng` 在目标机上构建 `packages.x86_64-linux.kexec-installer`（nixos-images 模块 + 本仓 nixpkgs + 默认 LTS 内核）并 kexec 进去。
3. 安装环境内核比目标内核新就中止。
4. 再跑 disko、install、reboot。

该镜像去掉上游 `restore-remote-access.nix`、只复用它的 initrd 服务，因为该模块仍写着已移除的 `boot.initrd.systemd.enable`。

## 缓存

`just install` 有意**不**传 substituters、keys 或 experimental-features。nixos-anywhere 默认 `machineSubstituters=y`，会读目标的 `nix.settings.{substituters,trusted-public-keys}` 并追加到安装器的 `~/.config/nix/nix.conf`，每次 nix 调用也都带 `--extra-experimental-features 'nix-command flakes'`（`src/nixos-anywhere.sh`）。手写缓存列表会与 `nix.settings` 悄悄漂移。只有 `--no-substitute-on-destination` / `--no-use-machine-substituters` 能关掉它，`--option` 不行。

## 磁盘布局

- `single-disk` adapter（`modules/nixos/single-disk.nix`）：GPT，ESP 挂 `/boot` 配合 systemd-boot，默认 512M，其余为 ext4 根分区。host 设 `disko.devices.disk.main.device`：`awesome-pc` 用 by-id 并把 ESP 设为 1G；`homelab-server` 与 `mihomo-gateway` 默认 `/dev/sda`，PVE 或目标机呈现其他设备时，首装前改 host 里的默认值。
- `grub-raid` adapter（`modules/nixos/grub-raid.nix`）：OVH 双 NVMe（`/dev/nvme{0,1}n1`）。ESP RAID1（vfat 512M，md metadata 1.0，挂 `/boot/efi`），`/boot` RAID1（ext4 2G，metadata 1.2），root md（默认 RAID1，metadata 1.2），GRUB hybrid/removable 引导。`awesome-devbox` 把 root 改为 RAID0 且不做备份：坏任一块盘即重装并丢数据。
- 布局只在首装时执行，但同时决定 `fileSystems`。改布局或移动布局代码后，对比各 host 的 `config.system.build.diskoScript.drvPath`。

## 解密身份

安装器不携带 SOPS 解密身份。首装后先运行一次 `just deploy <host> <remote>`：`scripts/sops-key.sh` 从 host 配置读取 `sops.age.keyFile`，核对 SSH 主机身份和主机名，再把调用端 SSH 私钥派生的 age 身份写到目标机。重装后用同一把私钥重新部署即可。
