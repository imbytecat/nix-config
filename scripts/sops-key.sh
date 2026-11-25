#!/usr/bin/env bash
# 首次激活前把 SOPS 解密身份装到目标机。身份由调用端的 SSH 私钥派生，SSH 登录私钥留在调用端。
# 用法：scripts/sops-key.sh <nixos|darwin> <host> [remote]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

class=$1
host=$2
remote=${3:-}
config=".#${class}Configurations.$host.config"

# 身份路径以 host 配置为准；不用 SOPS 的 host（服务器）没有 keyFile，直接跳过。
key=$(nix eval --raw "$config" --apply 'c: c.sops.age.keyFile or ""')
[[ -n "$key" ]] || exit 0

if [[ -n "$remote" ]]; then
  run=(ssh -T -o StrictHostKeyChecking=ask "root@$remote")
else
  run=(sudo)
fi
actual=$("${run[@]}" hostname -s)
[[ "$actual" == "$host" ]] || {
  echo "refuse: hostname=$actual != $host" >&2
  exit 1
}
if "${run[@]}" test -s "$key"; then exit 0; fi

# 发送任何秘密前，先确认调用端的私钥能解开这份密文。
sops_file=$(nix eval --raw "$config.sops.defaultSopsFile")
# shellcheck disable=SC2016 # $1 与 $SOPS_AGE_KEY_CMD 在 devShell 里展开。
identity=$(nix develop -c bash -ec 'sops decrypt "$1" >/dev/null; exec "$SOPS_AGE_KEY_CMD"' _ "$sops_file")

# 目标端从 stdin 读两行：身份路径、身份。先写临时文件再 ln：已有文件不覆盖，内容相同视为成功。
# shellcheck disable=SC2016 # 脚本在目标端由 sh 展开。
install_key='set -eu
umask 077
IFS= read -r key
IFS= read -r identity
case "$identity" in AGE-SECRET-KEY-1*) ;; *) exit 1 ;; esac
dir=$(dirname "$key")
mkdir -p "$dir"
tmp=$(mktemp "$dir/.key.XXXXXX")
trap "rm -f -- $tmp" EXIT
echo "$identity" > "$tmp"
ln "$tmp" "$key" || cmp -s "$tmp" "$key"'
if [[ -n "$remote" ]]; then
  printf '%s\n' "$key" "$identity" | ssh -T -o StrictHostKeyChecking=yes "root@$remote" "$install_key"
else
  printf '%s\n' "$key" "$identity" | sudo sh -c "$install_key"
fi
