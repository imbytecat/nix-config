#!/usr/bin/env bash
# NixOS Live / installer 本机首装（不依赖 just / 预先开 flakes）
#
# Live 一键（root）：
#   curl -fsSL https://raw.githubusercontent.com/imbytecat/nix-config/main/scripts/install-local.sh \
#     | bash -s -- awesome-pc
#
# 已 clone 本仓时：
#   sudo ./scripts/install-local.sh awesome-pc
#
# 环境变量（可选）：
#   REPO_URL   默认 https://github.com/imbytecat/nix-config
#   REPO_REF   默认 main
#   WORKDIR    默认 /tmp/nix-config（curl|bash 时 clone/解压到这里）
#
# 警告：会按 hosts/<host>/disko.nix 全盘 wipe。

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/imbytecat/nix-config}"
REPO_REF="${REPO_REF:-main}"
WORKDIR="${WORKDIR:-/tmp/nix-config}"

usage() {
  cat <<'EOF' >&2
Usage: install-local.sh <host>

  Live 一键:
    curl -fsSL https://raw.githubusercontent.com/imbytecat/nix-config/main/scripts/install-local.sh \
      | bash -s -- awesome-pc

  本地 clone:
    sudo ./scripts/install-local.sh awesome-pc

Env: REPO_URL REPO_REF WORKDIR
EOF
  exit 2
}

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

[[ $# -eq 1 ]] || usage
host="$1"
[[ "$host" =~ ^[a-zA-Z0-9_-]+$ ]] || die "invalid host name: $host"

# Live 默认无 flakes；accept-flake-config 让 flake.nix 的 nixConfig（cache）生效
export NIX_CONFIG="${NIX_CONFIG:-}
experimental-features = nix-command flakes
accept-flake-config = true
"

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo --preserve-env=NIX_CONFIG,NIX_BUILD_CORES,NIXPKGS_ALLOW_UNFREE "$@"
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 若系统无 git，用 ISO nixpkgs 临时提供（不依赖 flake）；失败返回 1 走 tarball
git_cmd() {
  if have_cmd git; then
    git "$@"
  else
    # 参数经 bash -c 传入，避免再嵌一层 quote 地狱
    local q=()
    local a
    for a in "$@"; do
      q+=("$(printf '%q' "$a")")
    done
    run_as_root nix-shell -p git --run "git ${q[*]}"
  fi
}

fetch_repo_git() {
  if [[ -d "${WORKDIR}/.git" ]]; then
    log "reusing existing git repo at ${WORKDIR}"
    git_cmd -C "$WORKDIR" fetch --depth 1 origin "$REPO_REF"
    git_cmd -C "$WORKDIR" checkout -B "$REPO_REF" FETCH_HEAD
  else
    run_as_root rm -rf "$WORKDIR"
    git_cmd clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$WORKDIR"
  fi
}

fetch_repo_tarball() {
  have_cmd curl || die "need git or curl to fetch repo"
  have_cmd tar || die "need tar to extract repo archive"
  local archive_url tarball
  archive_url="${REPO_URL}/archive/refs/heads/${REPO_REF}.tar.gz"
  tarball="$(mktemp)"
  log "fetching archive ${archive_url}"
  curl -fsSL "$archive_url" -o "$tarball"
  run_as_root rm -rf "$WORKDIR"
  run_as_root mkdir -p "$WORKDIR"
  run_as_root tar -xzf "$tarball" -C "$WORKDIR" --strip-components=1
  rm -f "$tarball"
}

# ── 定位 / 准备仓库 ──────────────────────────────────────────
resolve_repo() {
  # 1) 当前目录就是本仓
  if [[ -f ./flake.nix && -d ./hosts ]]; then
    pwd -P
    return
  fi

  # 2) 脚本在仓库里（./scripts/install-local.sh）
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" && -f "$src" ]]; then
    local script_dir repo
    script_dir="$(cd "$(dirname "$src")" && pwd -P)"
    repo="$(cd "${script_dir}/.." && pwd -P)"
    if [[ -f "${repo}/flake.nix" && -d "${repo}/hosts" ]]; then
      printf '%s\n' "$repo"
      return
    fi
  fi

  # 3) curl|bash 或孤立脚本：拉仓库到 WORKDIR
  log "repo not found nearby; fetching ${REPO_URL}@${REPO_REF} → ${WORKDIR}"
  if have_cmd git || run_as_root nix-shell -p git --run 'command -v git' >/dev/null 2>&1; then
    fetch_repo_git
  else
    log "git unavailable; falling back to GitHub tarball"
    fetch_repo_tarball
  fi

  [[ -f "${WORKDIR}/flake.nix" && -d "${WORKDIR}/hosts" ]] || die "fetched tree missing flake.nix/hosts"
  printf '%s\n' "$WORKDIR"
}

# ── 主流程 ──────────────────────────────────────────────────
main() {
  have_cmd nix || die "nix not found (boot NixOS installer ISO)"

  local repo
  repo="$(resolve_repo)"
  cd "$repo"
  log "using repo: $repo"

  local disko hardware_config
  disko="./hosts/${host}/disko.nix"
  hardware_config="./hosts/${host}/hardware-configuration.nix"
  [[ -f "$disko" ]] || die "${disko} missing（install-local 需要 disko）"

  log "WARNING: disko will wipe disks in hosts/${host}/disko.nix"
  log "---- lsblk ----"
  lsblk -o NAME,MODEL,SIZE,TYPE,SERIAL 2>/dev/null || lsblk || true
  log "---- by-id (nvme/ata) ----"
  ls -1 /dev/disk/by-id 2>/dev/null | grep -E '^(nvme|ata)-' | grep -v -- '-part' || true
  log "---------------"
  local answer
  read -r -p "Type '${host}' to confirm wipe and install: " answer
  [[ "$answer" == "$host" ]] || die "aborted"

  if [[ -f "$hardware_config" ]] && have_cmd nixos-generate-config; then
    log "regenerating ${hardware_config} from live hardware..."
    nixos-generate-config --no-filesystems --show-hardware-config >"$hardware_config"
  fi

  local nix_options=(
    --option extra-substituters "https://nix-community.cachix.org https://nixpkgs-unfree.cachix.org https://cache.numtide.com https://catppuccin.cachix.org"
    --option extra-trusted-public-keys "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
  )

  log "running disko-install for #${host} ..."
  # --mode format：全盘；--write-efi-boot-entries：本机 UEFI 写 NVRAM
  run_as_root nix --extra-experimental-features "nix-command flakes" run \
    github:nix-community/disko/latest#disko-install -- \
    --flake "${repo}#${host}" \
    --mode format \
    --write-efi-boot-entries \
    "${nix_options[@]}"

  log "install-local done. reboot when ready."
  if [[ -f "$hardware_config" ]]; then
    log "if hardware-configuration.nix was regenerated, commit it after first boot."
  fi
}

main
