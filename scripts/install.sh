#!/bin/bash
# NixOS 配置安装脚本
# 在 NixOS-WSL 或裸机 NixOS 中运行
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/nix-config.git"
CONFIG_DIR="$HOME/.config/nix-config"
FLAKE_TARGET="${1:-wsl}" # 默认 wsl，裸机传入 bare

echo "📥 获取配置仓库..."
if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo "⏩ 仓库已存在，拉取最新..."
    git -C "$CONFIG_DIR" pull
else
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

echo "⚙️ 应用系统配置（目标: $FLAKE_TARGET）..."
sudo nixos-rebuild switch --flake "$CONFIG_DIR#$FLAKE_TARGET"

echo ""
echo "🎉 安装完成！请重新登录以使用 zsh。"
echo ""
echo "后续更新："
echo "  cd $CONFIG_DIR && git pull && sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
