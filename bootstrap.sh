#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 安装 yay..."
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
fi

echo "==> 安装 dcli..."
yay -S --needed --noconfirm dcli-arch-git

echo "==> 链接配置..."
rm -rf ~/.config/arch-config
ln -sf "$SCRIPT_DIR/arch-config" ~/.config/arch-config

echo ""
echo "✓ Bootstrap 完成！"
echo ""
echo "下一步："
echo "  1. 检查配置: ~/.config/arch-config/"
echo "  2. 应用配置: dcli sync"
