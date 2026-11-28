#!/usr/bin/env bash
# just lint 与 checks.lint 共用；工具由 devShell 或 check 的 nativeBuildInputs 提供。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

statix check

# hardware-configuration.nix 由 nixos-generate-config 生成，不由我们维护。
mapfile -t generated < <(find ./hosts -name hardware-configuration.nix)
args=(--fail)
if ((${#generated[@]} > 0)); then args+=(--exclude "${generated[@]}"); fi
deadnix "${args[@]}"

shellcheck scripts/*.sh
ruff check --no-cache .
