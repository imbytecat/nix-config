#!/usr/bin/env bash
# 远程首装：引导 kexec → 在目标机上构建同内核 kexec → disko 全盘 → install → reboot。
# 用法：scripts/install.sh <host> <remote>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

host=$1
remote=$2
target="root@$remote"
ssh_opts=(-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR)
export NIX_SSHOPTS="${ssh_opts[*]}"

hardware_config="./hosts/$host/hardware-configuration.nix"
hardware_args=()
# 只对 git tracked 的 hardware config 请求重新生成；未跟踪文件不会进入目标 build。
if git ls-files --error-unmatch "$hardware_config" >/dev/null 2>&1; then
  hardware_args+=(--generate-hardware-config nixos-generate-config "$hardware_config")
fi

# 两次 kexec 之间用本机密钥登录；kexec 环境继承上一环境 root 的 authorized_keys。
ssh-copy-id "${ssh_opts[@]}" "$target"

# 第一次只为在目标机上拿到 Nix；上游镜像内核比目标新，不能让它建 md 阵列（见 modules/flake/install.nix）。
nix run .#nixos-anywhere -- \
  --phases kexec \
  --kexec "$(nix build --no-link --print-out-paths .#kexec-bootstrap)" \
  --flake ".#$host" \
  --target-host "$target"

kexec="$(nix build --no-link --print-out-paths --eval-store auto --store "ssh-ng://$target" .#packages.x86_64-linux.kexec-installer)"
# shellcheck disable=SC2029 # store 路径在本机展开，tarball 的 glob 在目标机展开。
ssh "${ssh_opts[@]}" "$target" "mkdir -p /root/kexec && tar -xzf $kexec/*.tar.gz -C /root/kexec && TMPDIR=/root/kexec setsid --wait /root/kexec/kexec/run"

# 新环境是全新 initrd，没有 /root/kexec；看到它消失才算切换完成。
for _ in $(seq 60); do
  sleep 5
  ssh "${ssh_opts[@]}" "$target" 'test ! -e /root/kexec' && break
done

got="$(ssh "${ssh_opts[@]}" "$target" uname -r)"
want="$(nix eval --raw ".#nixosConfigurations.$host.config.boot.kernelPackages.kernel.modDirVersion")"
if [[ "$(printf '%s\n' "$got" "$want" | sort -V | tail -1)" != "$want" ]]; then
  echo "安装环境内核 $got 比目标 $want 新，建出的 md 阵列目标组装不了" >&2
  exit 1
fi

# nixos-anywhere 会转发目标 host 的 nix.settings 并自动启用 flakes；勿在此复制。
nix run .#nixos-anywhere -- \
  "${hardware_args[@]}" \
  --phases disko,install,reboot \
  --option always-allow-substitutes true \
  --flake ".#$host" \
  --target-host "$target" \
  --build-on remote
