#!/bin/bash
# NixOS / standalone Home Manager 安装脚本
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/nix-config.git"
CONFIG_DIR="$HOME/.config/nix-config"
FLAKE_TARGET="${1:-wsl}" # wsl (default), bare, or home

echo "📥 获取配置仓库..."
if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo "⏩ 仓库已存在，拉取最新..."
    git -C "$CONFIG_DIR" pull
else
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

echo "⚙️ 应用配置（目标: $FLAKE_TARGET）..."

case "$FLAKE_TARGET" in
    wsl|bare)
        sudo nixos-rebuild switch --flake "$CONFIG_DIR#$FLAKE_TARGET"
        echo ""
        echo "🎉 安装完成！请重新登录以使用 zsh。"
        echo ""
        echo "后续更新："
        echo "  cd $CONFIG_DIR && git pull && sudo nixos-rebuild switch --flake .#$FLAKE_TARGET"
        ;;
    home)
        # Standalone home-manager（非 NixOS 系统：Ubuntu、Fedora、macOS 等）
        HM_USER="$(whoami)"
        if ! command -v home-manager &>/dev/null; then
            echo "📦 首次运行 home-manager..."
            nix run home-manager/master -- switch --flake "$CONFIG_DIR#$HM_USER"
        else
            home-manager switch --flake "$CONFIG_DIR#$HM_USER"
        fi
        echo ""
        echo "🎉 Home Manager 配置已应用！"
        echo ""
        echo "后续更新："
        echo "  cd $CONFIG_DIR && git pull && home-manager switch --flake .#$HM_USER"
        ;;
    *)
        echo "❌ 未知目标: $FLAKE_TARGET"
        echo "用法: $0 [wsl|bare|home]"
        echo "  wsl  — NixOS on WSL (默认)"
        echo "  bare — NixOS 裸机"
        echo "  home — 独立 Home Manager (非 NixOS)"
        exit 1
        ;;
esac
