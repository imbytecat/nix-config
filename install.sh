#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/archlinux-config.git"
CONFIG_DIR="$HOME/.config/arch-config"

echo "==> 更新系统..."
sudo pacman -Syu --noconfirm

echo "==> 安装基础工具..."
sudo pacman -S --needed --noconfirm base-devel git

echo "==> 安装 yay..."
if ! command -v yay &> /dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
fi

echo "==> 安装 dcli..."
yay -S --needed --noconfirm dcli-arch-git

echo "==> 克隆配置仓库..."
rm -rf "$CONFIG_DIR"
git clone "$REPO_URL" "$CONFIG_DIR"

echo ""
echo "✓ 安装完成！"
echo ""
echo "下一步："
echo "  cd ~/.config/arch-config"
echo "  dcli sync"
