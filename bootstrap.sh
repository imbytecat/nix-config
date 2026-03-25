#!/bin/bash
set -e

echo "==> 安装 yay..."
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
fi

echo "==> 安装 dcli..."
yay -S --needed --noconfirm dcli-arch-git

echo "==> 复制配置..."
mkdir -p ~/.config/arch-config
cp -r ./arch-config/* ~/.config/arch-config/

echo ""
echo "✓ Bootstrap 完成！"
echo ""
echo "下一步："
echo "  1. 检查配置: ~/.config/arch-config/"
echo "  2. 应用配置: dcli sync"
